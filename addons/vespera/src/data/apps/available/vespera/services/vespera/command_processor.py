import json
import logging
import os
import subprocess
import threading
from typing import Optional

log = logging.getLogger(__name__)

GUI_EXECUTOR_PATH = os.path.normpath(
	os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "scripts", "gui-executor"))

class CommandProcessor:
	"""Runs one gui-executor command at a time.

	gui-executor validates the command family/action and reports its progress and
	exit code through the /Settings/Vespera/Gui/* settings, so nothing is published here.
	"""

	def __init__(self):
		self._lock = threading.Lock()
		self._process: Optional[subprocess.Popen] = None

	def start_command(self, args_json: Optional[str] = None):
		"""Start gui-executor with args_json, a JSON array: [family, action, *args].

		Returns False so it can be used directly as a GLib.idle_add callback.
		"""
		try:
			args = json.loads(args_json or "[]")
			if not isinstance(args, list) or len(args) < 2:
				raise ValueError("expected [family, action, *args]")
			args = [str(a) for a in args if a is not None]
		except (TypeError, ValueError) as e:
			log.error("Rejecting start: invalid args %r: %s", args_json, e)
			return False

		if not os.access(GUI_EXECUTOR_PATH, os.X_OK):
			log.error("Rejecting start: %s not found or not executable", GUI_EXECUTOR_PATH)
			return False

		with self._lock:
			if self._process and self._process.poll() is None:
				log.warning("Rejecting start: command already running")
				return False

			log.info("Starting gui-executor: %s", args)
			try:
				# New session so the command survives this service being stopped,
				# e.g. when upgrading vespera itself restarts the service.
				process = subprocess.Popen(
					[GUI_EXECUTOR_PATH, *args],
					stdin=subprocess.DEVNULL,
					stdout=subprocess.DEVNULL,
					stderr=subprocess.DEVNULL,
					env={**os.environ, "VESPERA_FROM_SERVICE": "1"},
					# The service's own cwd can be deleted when vespera upgrades itself,
					# which makes the child shell fail with "getcwd: cannot access parent directories"
					cwd="/",
					start_new_session=True,
				)
			except OSError:
				log.exception("Failed to start gui-executor")
				return False
			self._process = process

		threading.Thread(target=self._wait_for_process, args=(process, args), daemon=True).start()
		return False

	def _wait_for_process(self, process: subprocess.Popen, args):
		exit_code = process.wait()
		log.info("gui-executor %s exited with code %s", args[:2], exit_code)
		with self._lock:
			if self._process is process:
				self._process = None
