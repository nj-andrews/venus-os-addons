import logging
from datetime import datetime, timedelta
from typing import Callable, Optional

import dbus
from gi.repository import GLib  # type: ignore

log = logging.getLogger(__name__)

# Longest single sleep; the wall clock is re-checked after each, so clock jumps (NTP/GPS) self-correct
AUTO_UPDATE_MAX_SLEEP_SECONDS = 3600
AUTO_UPDATE_WEEKDAY = 6  # 0=Monday ... 6=Sunday


class AutoUpdateScheduler:
		"""Runs a callback once a week at a configured time of day."""

		def __init__(self, on_fire: Callable[[], None]):
			self._on_fire = on_fire
			self._source_id: Optional[int] = None
			self._seconds = 0
			self._next: Optional[datetime] = None

		def set_schedule(self, value):
			"""Apply the setting value: "" disables, otherwise seconds from midnight."""
			if self._source_id is not None:
				GLib.source_remove(self._source_id)
				self._source_id = None
		self._next = None

			log.info("set_schedule: value=%r type=%s", value, type(value).__name__)
			if value is None or isinstance(value, (list, tuple, dbus.Array)) or str(value).strip() == "":
				log.info("Auto update schedule disabled")
				return

			try:
				seconds = int(float(value))
			except (TypeError, ValueError):
				raise ValueError(f"Invalid auto update value: {value!r}")
			if not 0 <= seconds < 86400:
				raise ValueError(f"Auto update time out of range: {seconds}")

			self._seconds = seconds
			self._next = self._next_update_time(seconds)
			log.info("Auto update scheduled at %s seconds from midnight, next run %s", seconds, self._next)
			self._arm_timer()

		@staticmethod
		def _next_update_time(seconds_from_midnight):
			now = datetime.now()
			target = now.replace(hour=0, minute=0, second=0, microsecond=0) + timedelta(seconds=seconds_from_midnight)
			target += timedelta(days=(AUTO_UPDATE_WEEKDAY - now.weekday()) % 7)
			if target <= now:
					target += timedelta(days=7)
			return target

		def _arm_timer(self):
			remaining = (self._next - datetime.now()).total_seconds()
			delay = max(1, min(int(remaining) + 1, AUTO_UPDATE_MAX_SLEEP_SECONDS))
			self._source_id = GLib.timeout_add_seconds(delay, self._on_timer)

		def _on_timer(self):
			self._source_id = None
			try:
				if self._next is None:
					return False

				now = datetime.now()
				if self._next - now > timedelta(days=7):
					# clock moved backwards; recompute
					self._next = self._next_update_time(self._seconds)
					log.info("Clock change detected, next auto update run %s", self._next)
				elif now >= self._next:
					log.info("Auto update timer fired (scheduled %s, now %s)", self._next, now)
					self._next = self._next_update_time(self._seconds)
					log.info("Next auto update run %s", self._next)
					self._on_fire()
			except Exception:
				log.exception("Auto update timer failed")
			if self._next is not None:
				self._arm_timer()
			return False
