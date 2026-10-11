import logging
import os
import json
import re
import time

import dbus
from gi.repository import GLib  # type: ignore

from vespera_config import VesperaConfig

log = logging.getLogger(__name__)

CHUNK_MAX_SIZE = 65536
CHUNK_DEFAULT_SIZE = 32768
CHUNK_SESSION_TTL_MS = 60000
CHUNK_CLEANUP_INTERVAL_MS = 5000
SESSION_ID_RE = re.compile(r"^[A-Za-z0-9_-]{8,64}$")

# Named data sources served via the /Chunk/ D-Bus API.
# Keys are the names the UI passes in RequestJson.name.

VESPERA_CONFIG = VesperaConfig()
CHUNK_SOURCE_REGISTRY = {
		"packages": VESPERA_CONFIG.get_path("VESPERA_JSON_PACKAGES_FILE"),
		"feeds": VESPERA_CONFIG.get_path("VESPERA_JSON_FEEDS_FILE"),
}


class ChunkProcessor:
		"""Serves named file data in chunks over per-session /Chunk/Sessions paths."""

		def __init__(self, dbusservice):
				self._dbusservice = dbusservice
				self._sessions = {}
				GLib.timeout_add(CHUNK_CLEANUP_INTERVAL_MS, self._cleanup_expired_sessions)

		def on_create_session_requested(self, _path, value):
				session_id = str(value or "").strip()
				if not self._is_valid_session_id(session_id):
						log.warning("Chunk create session rejected: invalid session id=%s", session_id)
						return False

				self._ensure_session(session_id)
				log.debug("Chunk session active session_id=%s", session_id)
				return True

		def on_close_session_requested(self, _path, value):
				session_id = str(value or "").strip()
				if not session_id:
						return True

				if session_id in self._sessions:
						self._delete_session(session_id, "client-close")
				return True

		def on_chunk_requested(self, _path, value):
				request_json = str(value or "")
				GLib.idle_add(self.serve_chunk_from_request, request_json)
				return True

		def serve_chunk_from_request(self, request_json):
				log.info("serve_chunk_from_request")
				try:
						request = json.loads(request_json)
						if not isinstance(request, dict):
								raise ValueError("request must be an object")
				except Exception as err:
						log.warning("Chunk request rejected: invalid JSON (%s)", err)
						return False

				session_id = str(request.get("sessionId") or "").strip()
				name = str(request.get("name") or "").strip()
				offset = int(request.get("offset") or 0)
				max_size = int(request.get("maxSize") or CHUNK_DEFAULT_SIZE)
				req_seq = int(request.get("seq") or 0)

				if not self._is_valid_session_id(session_id):
						log.warning("Chunk request rejected: invalid session id=%s", session_id)
						return False

				self._ensure_session(session_id)
				self._touch_session(session_id)
				result_root = self._session_result_root(session_id)

				self._dbusservice[result_root + "/Data"] = ""
				self._dbusservice[result_root + "/EndOfData"] = dbus.UInt16(0)
				self._dbusservice[result_root + "/SourceVersion"] = ""
				self._dbusservice[result_root + "/Error"] = ""

				if req_seq <= 0:
						self._dbusservice[result_root + "/Error"] = "seq must be > 0"
						self._dbusservice[result_root + "/Seq"] = dbus.UInt32(0)
						log.warning("Chunk request rejected: invalid seq=%s session=%s", req_seq, session_id)
						return False

				if not name:
						self._dbusservice[result_root + "/Error"] = "Name is required"
						self._dbusservice[result_root + "/Seq"] = dbus.UInt32(req_seq)
						log.warning("Chunk request rejected: missing name session=%s", session_id)
						return False

				file_path = CHUNK_SOURCE_REGISTRY.get(name)
				log.info("file_path= %s", file_path)
				if file_path is None:

						self._dbusservice[result_root + "/Error"] = f"Unknown source: {name}"
						self._dbusservice[result_root + "/Seq"] = dbus.UInt32(req_seq)
						log.warning("Chunk request rejected: unknown source name=%s session=%s", name, session_id)
						return False

				if not os.path.isfile(file_path):
						self._dbusservice[result_root + "/Error"] = f"Source not available: {name}"
						self._dbusservice[result_root + "/Seq"] = dbus.UInt32(req_seq)
						log.warning("Chunk source missing name=%s path=%s session=%s", name, file_path, session_id)
						return False

				try:
						max_size = max(1, min(max_size, CHUNK_MAX_SIZE))
						offset = max(0, offset)
						mtime = str(int(os.path.getmtime(file_path) * 1000))

						with open(file_path, "rb") as fh:
								fh.seek(offset)
								chunk = fh.read(max_size)
								end_pos = fh.tell()

						file_size = os.path.getsize(file_path)
						end_of_data = 1 if end_pos >= file_size else 0

						self._dbusservice[result_root + "/Data"] = chunk.decode("utf-8")
						self._dbusservice[result_root + "/EndOfData"] = dbus.UInt16(end_of_data)
						self._dbusservice[result_root + "/SourceVersion"] = mtime
						log.debug(
								"Chunk served session=%s name=%s bytes=%s end_of_data=%s",
								session_id,
								name,
								len(chunk),
								end_of_data,
						)
				except Exception as err:
						self._dbusservice[result_root + "/Error"] = f"Read error: {err}"
						log.exception("Chunk read error session=%s name=%s path=%s", session_id, name, file_path)

				self._dbusservice[result_root + "/Seq"] = dbus.UInt32(req_seq)
				return False

		def _ensure_session(self, session_id):
				root = self._session_root(session_id)
				result_root = self._session_result_root(session_id)

				if root + "/State" not in self._dbusservice:
						self._dbusservice.add_path(root + "/State", "active", valuetype=dbus.String)
				if root + "/LastAccessMs" not in self._dbusservice:
						self._dbusservice.add_path(root + "/LastAccessMs", dbus.UInt64(0), valuetype=dbus.UInt64)
				if result_root + "/Seq" not in self._dbusservice:
						self._dbusservice.add_path(result_root + "/Seq", dbus.UInt32(0), valuetype=dbus.UInt32)
				if result_root + "/Data" not in self._dbusservice:
						self._dbusservice.add_path(result_root + "/Data", "", valuetype=dbus.String)
				if result_root + "/EndOfData" not in self._dbusservice:
						self._dbusservice.add_path(result_root + "/EndOfData", dbus.UInt16(0), valuetype=dbus.UInt16)
				if result_root + "/SourceVersion" not in self._dbusservice:
						self._dbusservice.add_path(result_root + "/SourceVersion", "", valuetype=dbus.String)
				if result_root + "/Error" not in self._dbusservice:
						self._dbusservice.add_path(result_root + "/Error", "", valuetype=dbus.String)

				self._sessions[session_id] = self._now_ms()
				self._dbusservice[root + "/State"] = "active"
				self._dbusservice[root + "/LastAccessMs"] = dbus.UInt64(self._sessions[session_id])

		def _touch_session(self, session_id):
				now_ms = self._now_ms()
				self._sessions[session_id] = now_ms
				root = self._session_root(session_id)
				if root + "/LastAccessMs" in self._dbusservice:
						self._dbusservice[root + "/LastAccessMs"] = dbus.UInt64(now_ms)

		def _delete_session(self, session_id, reason):
				root = self._session_root(session_id)
				removed_paths = 0
				try:
						with self._dbusservice as svc:
								if hasattr(self._dbusservice, "_dbusobjects"):
										removed_paths = sum(
												1
												for p in self._dbusservice._dbusobjects.keys()
												if p == root or p.startswith(root + "/")
										)
								svc.del_tree(root)
				except Exception:
						log.exception("Chunk session cleanup failed session=%s reason=%s", session_id, reason)
				self._sessions.pop(session_id, None)
				if removed_paths > 0:
						log.debug(
								"Chunk session removed session=%s reason=%s paths=%s",
								session_id,
								reason,
								removed_paths,
						)
				else:
						log.debug(
								"Chunk session cleanup no-op session=%s reason=%s",
								session_id,
								reason,
						)

		def _cleanup_expired_sessions(self):
				now_ms = self._now_ms()
				expired = [
						session_id
						for session_id, last_access_ms in self._sessions.items()
						if now_ms - last_access_ms > CHUNK_SESSION_TTL_MS
				]
				for session_id in expired:
						self._delete_session(session_id, "ttl-expired")
				return True

		@staticmethod
		def _session_root(session_id):
				return f"/Chunk/Sessions/{session_id}"

		@staticmethod
		def _session_result_root(session_id):
				return f"/Chunk/Sessions/{session_id}/Result"

		@staticmethod
		def _is_valid_session_id(session_id):
				return bool(SESSION_ID_RE.match(session_id))

		@staticmethod
		def _now_ms():
				return int(time.time() * 1000)
