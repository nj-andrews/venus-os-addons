import asyncio
from datetime import datetime
from zoneinfo import ZoneInfo
from vedbus import VeDbusItemImport
from dbus_services.dbus_connection import dbusconnection

class InetboxSchedules:
	MINUTE_SEC = 60
	SECONDS_PER_DAY = 24 * 60 * 60
	STATE_PATH = "/Schedules/State"
	SCHEDULE_PATHS = {
		"/Schedules/Heating": 1,
		"/Schedules/Water": 2,
		"/Schedules/Aircon": 4,
	}

	def __init__(self, settings, apply_callback, logger):
		self._settings = settings
		self._apply_callback = apply_callback
		self._log = logger
		self._last_checked_minute = None
		self._settings_changed = asyncio.Event()
		self._timezone_item = None
		self._timezone_warned = False
		self._init_timezone_item()

	def on_setting_changed(self, path, oldvalue, newvalue):
		self._log.debug(f"inetbox_Schedules:on_setting_changed:in: path:{path},oldvalue:{oldvalue},newvalue:{newvalue}")
		if path.startswith("/Schedules/"):
			self._log.debug("Schedules setting changed: %s: %r -> %r", path, oldvalue, newvalue)
			if path.endswith("/Enabled"):
				path = path[:-8]
				self._log.debug(f"inetbox_Schedules:_refresh_state_btmask")
				self._update_state_bitmask(path, newvalue)

			self._settings_changed.set()

	def _update_state_bitmask(self, path, newvalue):
		state = self._get_setting(self.STATE_PATH)
		bit = self.SCHEDULE_PATHS[path]
		if (newvalue == 1):
			state |= bit
		else:
			state &= ~bit
		self._set_setting(self.STATE_PATH, state)

	async def run_loop(self):
		while True:
			now = self._now()
			minute_of_day = (now.hour * 60) + now.minute

			if minute_of_day != self._last_checked_minute:
				self._run_due_schedules(minute_of_day)
				self._last_checked_minute = minute_of_day

			self._settings_changed.clear()
			sleep_seconds = self._seconds_until_next_due(now)
			self._log.debug(f"inetbox_Schedules:run_loop:sleep_seconds: {sleep_seconds}")
			if sleep_seconds is None:
				await self._settings_changed.wait()
				continue

			try:
				await asyncio.wait_for(self._settings_changed.wait(), timeout=sleep_seconds)
			except asyncio.TimeoutError:
				pass

	def _run_due_schedules(self, minute_of_day):
		self._run_heating_schedule(minute_of_day)
		self._run_water_schedule(minute_of_day)
		self._run_aircon_schedule(minute_of_day)

	def _run_heating_schedule(self, minute_of_day):
		base_path = "/Schedules/Heating"
		if not self._is_due(base_path, minute_of_day):
			return

		heating_mode = self._read_value(base_path, "HeatingMode")
		if heating_mode is not None:
			self._log.debug(f"inetbox_Schedules:_apply_callback:/Values/HeatingMode: {heating_mode}")
			self._apply_callback("/Values/HeatingMode", heating_mode)

		heating_temp = self._read_value(base_path, "HeatingTargetTemp")
		if heating_temp is not None:
			self._log.debug(f"inetbox_Schedules:_apply_callback:/Values/HeatingTargetTemp: {heating_temp}")
			self._apply_callback("/Values/HeatingTargetTemp", heating_temp)

		self._disable_if_one_shot(base_path)

	def _run_water_schedule(self, minute_of_day):
		base_path = "/Schedules/Water"
		if not self._is_due(base_path, minute_of_day):
			return

		water_temp = self._read_value(base_path, "WaterTargetTemp")
		if water_temp is not None:
			self._apply_callback("/Values/WaterTargetTemp", water_temp)

		self._disable_if_one_shot(base_path)

	def _run_aircon_schedule(self, minute_of_day):
		base_path = "/Schedules/Aircon"
		if not self._is_due(base_path, minute_of_day):
			return

		aircon_mode = self._read_value(base_path, "AirconMode")
		if aircon_mode is not None:
			self._apply_callback("/Values/AirconMode", aircon_mode)

		aircon_fan_speed = self._read_value(base_path, "AirconFanSpeed")
		if aircon_fan_speed is not None:
			self._apply_callback("/Values/AirconFanSpeed", aircon_fan_speed)

		aircon_temp = self._read_value(base_path, "AirconTargetTemp")
		if aircon_temp is not None:
			self._apply_callback("/Values/AirconTargetTemp", aircon_temp)

		self._disable_if_one_shot(base_path)

	def _is_due(self, base_path, minute_of_day):
		enabled_path = f"{base_path}/Enabled"
		time_path = f"{base_path}/Time"

		enabled = self._to_boolean(self._get_setting(enabled_path))
		if not enabled:
			return False

		time_value = self._get_setting(time_path)
		scheduled_minute = self._to_minute_of_day(time_value)
		if scheduled_minute is None:
			self._log.warning("Invalid %s time value: %r", time_path, time_value)
			return False

		if scheduled_minute != minute_of_day:
			return False

		self._log.info("Running Schedules task for %s at minute %s", base_path, minute_of_day)
		return True

	def _disable_if_one_shot(self, base_path):
		enabled_path = f"{base_path}/Enabled"
		repeat_path = f"{base_path}/Repeat"
		repeat = self._to_boolean(self._get_setting(repeat_path))
		if not repeat:
			self._set_setting(enabled_path, 0)
			self._update_state_bitmask(enabled_path, 0)
			self._log.debug("Disabled one-shot schedule after run for %s", base_path)

	def _read_value(self, base_path, key):
		path = f"{base_path}/{key}"
		value = self._get_setting(path)
		if value is None:
			return None
		if isinstance(value, str) and value == "":
			return None
		return value

	def _get_setting(self, path):
		try:
			return self._settings[path]
		except Exception:
			return None

	def _set_setting(self, path, value):
		try:
			self._settings[path] = value

		except Exception as ex:
			self._log.warning("Failed to set Schedules setting %s=%r: %s", path, value, ex)

	def _to_minute_of_day(self, value):
		try:
			seconds = int(value)
		except (TypeError, ValueError):
			return None

		if seconds < 0 or seconds >= self.SECONDS_PER_DAY:
			return None

		return seconds // 60

	def _to_boolean(self, value):
		if isinstance(value, bool):
			return value
		if isinstance(value, int) and value in (0, 1):
			return bool(value)
		return False

	def _seconds_until_next_due(self, now):

		self._log.debug(f"inetbox_Schedules:_seconds_until_next_due: hour:{now.hour}, minutes:{now.minute}")

		now_seconds = (now.hour * 3600) + (now.minute * 60) + now.second + (now.microsecond / 1_000_000)
		next_delta = None

		state = (self._get_setting(self.STATE_PATH))
		if (state == 0):
			return

		for base_path, bit in self.SCHEDULE_PATHS.items():
			if not state & bit:
				continue

			time_value = self._get_setting(f"{base_path}/Time")
			try:
				scheduled_seconds = int(time_value)
			except (TypeError, ValueError):
				continue

			if scheduled_seconds < 0 or scheduled_seconds >= self.SECONDS_PER_DAY:
				continue

			delta = scheduled_seconds - now_seconds
			if delta <= 0:
				delta += self.SECONDS_PER_DAY

			if next_delta is None or delta < next_delta:
				next_delta = delta

		if next_delta is None:
			return None

		# Wake up at the start of the minute in which the schedule should run.
		seconds_until_due_minute = max(0.1, next_delta - (next_delta % self.MINUTE_SEC))
		return seconds_until_due_minute

	def _init_timezone_item(self):
		if VeDbusItemImport is None or dbusconnection is None:
			return
		try:
			self._timezone_item = VeDbusItemImport(
				dbusconnection(),
				"com.victronenergy.settings",
				"/Settings/System/TimeZone",
				createsignal=False,
			)
		except Exception as ex:
			self._log.debug("Schedules could not initialize timezone item: %r", ex)

	def _now(self):
		timezone_name = None
		if self._timezone_item is not None:
			try:
				timezone_name = self._timezone_item.get_value()
			except Exception as ex:
				if not self._timezone_warned:
					self._log.warning("Schedules could not read /Settings/System/TimeZone: %r", ex)
					self._timezone_warned = True

		if ZoneInfo is not None and isinstance(timezone_name, str) and timezone_name:
			try:
				return datetime.now(ZoneInfo(timezone_name))
			except Exception as ex:
				if not self._timezone_warned:
					self._log.warning("Schedules invalid timezone '%s': %r", timezone_name, ex)
					self._timezone_warned = True

		return datetime.now()
