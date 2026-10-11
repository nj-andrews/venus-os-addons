import json
import logging
import os
import signal
import subprocess
import threading
import uuid
from typing import List, Optional

import dbus
from gi.repository import GLib  # type: ignore

from command_state import CommandState

log = logging.getLogger(__name__)

VESPERA_PATH = "/data/apps/available/vespera/vespera"
VESPERA_WORKDIR = "/"

COMMAND_REGISTRY = {
	"packages": {
		"default": {
			"helper_name": "vespera",
			"helper_path": f"{VESPERA_PATH}",
		},
		"actions": {
			"update": {},
		},
	},
	"feed": {
		"default": {
			"helper_name": "vespera",
			"helper_path": f"{VESPERA_PATH}",
		},
		"actions": {
			"add": {"prefix_args": ["feed-source"]},
			"edit": {"prefix_args": ["feed-source"]},
			"remove": {"prefix_args": ["feed-source"]},
		},
	},
	"package": {
		"default": {
			"helper_name": "vespera",
			"helper_path": f"{VESPERA_PATH}",
		},
		"actions": {
			"install": {"prefix_args": ["--in-gui"]},
			"remove":  {"prefix_args": ["--in-gui"]},
			"upgrade": {"prefix_args": ["--in-gui"]},
			"enable": {"prefix_args": ["--in-gui"]},
			"disable": {"prefix_args": ["--in-gui"]},
		},
	},
	"device": {
		"default": {
			"helper_name": "vespera",
			"helper_path": f"{VESPERA_PATH}",
		},
		"actions": {
			"scan": {"prefix_args": ["device"]},
			"bind": {"prefix_args": ["device"]},
			"remove": {"prefix_args": ["device"]},
		},
	},
}


class CommandProcessor:
		"""Manages the full lifecycle of a single concurrent helper-process command."""

		def __init__(self, dbusservice, lock: threading.RLock, usb_scanner):
				self._dbusservice = dbusservice
				self._lock = lock
				self._active: Optional[CommandState] = None
				self._usb_scanner = usb_scanner

		# ------------------------------------------------------------------
		# Public interface called from the service bootstrap
		# ------------------------------------------------------------------

		def mark_cancelled_sync(self):
				"""Mark the active command as cancelled (must be called from the main thread).

				This is called synchronously inside the D-Bus on_cancel callback so that
				any drain idle callbacks already queued in GLib will see the flag and
				skip emission when they run.
				"""
				with self._lock:
						state = self._active
				if state:
						state.cancelled = True

		def start_command(self):
				with self._lock:
						if self._active and self._active.process.poll() is None:
								log.warning("Rejecting start: command already running")
								self._set_error("Command already running")
								return False

				args_json = str(self._dbusservice["/Request/ArgsJson"] or "[]")

				try:
						args = json.loads(args_json)
						if not isinstance(args, list):
								raise ValueError("ArgsJson must contain a JSON array")
						args = [str(arg) for arg in args]
						log.info("Parsed request args: %s", args)
				except Exception as err:
						self._finish_start_error(f"Invalid args json: {err}")
						return False

				try:
						helper_name, helper_path, helper_args, operation_name = self.resolve_command(args)
						log.info(
								"Resolved command operation=%s helper=%s path=%s args=%s",
								operation_name,
								helper_name,
								helper_path,
								helper_args,
						)
				except ValueError as err:
						self._finish_start_error(str(err))
						return False
				log.info(operation_name)
				if operation_name == "device scan":
						self._usb_scanner.clear_discovered_devices()
				log.info([helper_path] + helper_args)
				self._reset_result_state()

				try:
						process = subprocess.Popen(
								[helper_path] + helper_args,
								stdout=subprocess.PIPE,
								stderr=subprocess.STDOUT,
								text=True,
								bufsize=1,
								universal_newlines=True,
								start_new_session=True,
						)
						log.info("Started process pid=%s operation=%s", process.pid, operation_name)
				except Exception as err:
						self._finish_start_error(f"Failed to start process: {err}")
						return False

				state = CommandState(
						request_id=str(uuid.uuid4()),
						helper_name=helper_name,
						helper_path=helper_path,
						args=helper_args,
						operation_name=operation_name,
						process=process,
						stderr_done=True,
				)

				with self._lock:
						self._active = state

				self._dbusservice["/State/Status"] = dbus.UInt16(1)  # running

				threading.Thread(target=self._stream_output, args=(state,), daemon=True).start()
				threading.Thread(target=self._wait_for_process, args=(state,), daemon=True).start()
				return False

		def cancel_command(self):
				with self._lock:
						state = self._active

				if not state:
						log.info("Cancel requested with no active process")
						return False

				state.cancelled = True
				self._cancel_pending_drain(state)

				if state.process.poll() is not None:
						log.info("Cancel requested but process already exited; suppressing remaining output")
						return False

				self._dbusservice["/State/Status"] = dbus.UInt16(3)  # cancelling
				log.info("Stopping process pid=%s operation=%s", state.process.pid, state.operation_name)

				try:
						os.killpg(state.process.pid, signal.SIGTERM)
				except Exception:
						try:
								state.process.terminate()
						except Exception:
								pass

				return False

		def resolve_command(self, args: List[str]):
				if len(args) < 2:
						raise ValueError("Expected args: <family> <action> [args...]")

				family = args[0].strip()
				action = args[1].strip()
				if not family or not action:
						raise ValueError("Family and action are required")

				family_spec = COMMAND_REGISTRY.get(family)
				if not family_spec:
						raise ValueError(f"Unsupported command family: {family}")

				action_spec = family_spec["actions"].get(action)
				if action_spec is None:
						raise ValueError(f"Unsupported {family} action: {action}")

				helper_name = family_spec["default"]["helper_name"]
				helper_path = action_spec.get("helper_path") or family_spec["default"]["helper_path"]
				prefix_args = action_spec.get("prefix_args", [])
				helper_args_override = action_spec.get("helper_args")

				if not os.path.isfile(helper_path):
						raise ValueError(f"Helper not found: {helper_path}")
				if not os.access(helper_path, os.X_OK):
						raise ValueError(f"Helper not executable: {helper_path}")

				if helper_args_override is None:
						helper_args = [*prefix_args, action, *args[2:]]
				else:
						helper_args = [*helper_args_override, *args[2:]]
				operation_name = f"{family} {action}"
				return helper_name, helper_path, helper_args, operation_name

		# ------------------------------------------------------------------
		# Internal helpers
		# ------------------------------------------------------------------

		def _cancel_pending_drain(self, state: CommandState):
				with self._lock:
						drain_source_id = state.drain_source_id
						state.drain_source_id = 0
						state.output_queue.clear()
						state._drain_pending = False

				if drain_source_id:
						try:
								GLib.source_remove(drain_source_id)
						except Exception:
								pass

		def _stream_output(self, state: CommandState):
				log.info(f"_stream_output")
				stream = state.process.stdout
				if stream is None:
						self._mark_stream_done(state, True)
						return
				try:

						for raw_line in stream:
								if state.cancelled:
										break

								line = raw_line.rstrip("\r\n")

								if not self._usb_scanner.handle_line(state, line):
										state.output_queue.append(line)

								with self._lock:
										if not state._drain_pending and not state.cancelled:
												state._drain_pending = True
												state.drain_source_id = GLib.idle_add(self._drain_output, state)
				finally:
						self._mark_stream_done(state, True)

		def _drain_output(self, state: CommandState):
				with self._lock:
						state.drain_source_id = 0
						if state.cancelled:
								state.output_queue.clear()
								state._drain_pending = False
								return False

				# Process a small batch so the main loop stays responsive to D-Bus events.
				batch = 10
				for _ in range(batch):
						if state.cancelled:
								break
						if state.output_queue:
								line = state.output_queue.popleft()
								self._dbusservice["/Event/StdoutLine"] = line
								self._dbusservice["/Event/StdoutSeq"] = dbus.UInt32(int(self._dbusservice["/Event/StdoutSeq"]) + 1)
						else:
								break

				with self._lock:
						if state.cancelled:
								state.output_queue.clear()
								state._drain_pending = False
						elif state.output_queue:
								state.drain_source_id = GLib.idle_add(self._drain_output, state)
						else:
								state._drain_pending = False
				return False

		def _mark_stream_done(self, state: CommandState, is_stdout: bool):
				with self._lock:
						if self._active is not state:
								return
						if is_stdout:
								state.stdout_done = True
						else:
								state.stderr_done = True
						self._maybe_finish_command_locked(state)

		def _wait_for_process(self, state: CommandState):
				exit_code = 1
				exit_status = 1
				try:
						rc = state.process.wait()
						exit_code = int(rc)
						exit_status = 0
						log.info("Process exited pid=%s operation=%s code=%s", state.process.pid, state.operation_name, exit_code)
				except Exception:
						log.exception("Error while waiting for process pid=%s operation=%s", state.process.pid, state.operation_name)

				with self._lock:
						if self._active is not state:
								return
						state.exit_code = exit_code
						state.exit_status = exit_status
						state.wait_done = True
						self._maybe_finish_command_locked(state)

		def _maybe_finish_command_locked(self, state: CommandState):
				if self._active is not state or state.finish_scheduled:
						return

				if not (state.wait_done and state.stdout_done and state.stderr_done):
						return

				state.finish_scheduled = True
				GLib.idle_add(self._finish_command, state, state.exit_code, state.exit_status)

		def _finish_command(self, state: Optional[CommandState], exit_code: int, exit_status: int):
				with self._lock:
						active = self._active
						if state is not None and active is not state:
								return False
						self._active = None

				self._dbusservice["/State/Status"] = dbus.UInt16(0)
				self._dbusservice["/Result/ExitCode"] = dbus.Int32(exit_code)
				self._dbusservice["/Result/ExitStatus"] = dbus.UInt16(exit_status)

				if state and state.cancelled:
						self._dbusservice["/Result/Error"] = ""

				log.info(
						"Finished request_id=%s exit_code=%s exit_status=%s error=%s",
						state.request_id if state else 0,
						exit_code,
						exit_status,
						self._dbusservice["/Result/Error"],
				)

				self._dbusservice["/Event/FinishedSeq"] = dbus.UInt32(int(self._dbusservice["/Event/FinishedSeq"]) + 1)
				return False

		def _set_error(self, message: str):
				self._dbusservice["/Result/Error"] = message
				log.error("Result error set: %s", message)

		def _finish_start_error(self, message: str):
				self._reset_result_state()
				self._set_error(message)
				self._finish_command(None, 1, 1)

		def _reset_result_state(self):
				self._dbusservice["/Result/ExitCode"] = dbus.Int32(0)
				self._dbusservice["/Result/ExitStatus"] = dbus.UInt16(0)
				self._dbusservice["/Result/Error"] = ""
