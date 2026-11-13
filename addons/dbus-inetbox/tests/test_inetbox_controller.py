import importlib.util
import logging
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import Mock, patch


SERVICE = Path(__file__).resolve().parents[1] / "src/data/apps/available/dbus-inetbox/services/dbus-inetbox"


def load_controller():
	modules = {}
	for name, attribute in (
		("dbus_services.dbus_constants", "dbus_constants"),
		("dbus_services.dbus_connection", "dbusconnection"),
		("ext.settingsdevice", "SettingsDevice"),
		("lin", "Lin"),
		("inetboxapp", "InetboxApp"),
		("inetbox_schedules", "InetboxSchedules"),
		("taskmanager", "TaskManager"),
		("error_parser", "get_error_description"),
		("dbus_services.dbus_inetbox_service", "dbusInetboxService"),
	):
		module = types.ModuleType(name)
		setattr(module, attribute, object)
		modules[name] = module
	spec = importlib.util.spec_from_file_location("inetbox_controller_test_module", SERVICE / "inetbox_controller.py")
	module = importlib.util.module_from_spec(spec)
	with patch.dict(sys.modules, modules):
		spec.loader.exec_module(module)
	return module.InetboxController


InetboxController = load_controller()


def load_schedules():
	vedbus = types.ModuleType("vedbus")
	vedbus.VeDbusItemImport = object
	connection = types.ModuleType("dbus_services.dbus_connection")
	connection.dbusconnection = object
	spec = importlib.util.spec_from_file_location("inetbox_schedules_test_module", SERVICE / "inetbox_schedules.py")
	module = importlib.util.module_from_spec(spec)
	with patch.dict(sys.modules, {"vedbus": vedbus, "dbus_services.dbus_connection": connection}):
		spec.loader.exec_module(module)
	return module.InetboxSchedules


class FakeSettings(dict):
	def __setitem__(self, key, value):
		if key == "/LastHeatingTemp":
			assert isinstance(value, int) and 4 <= value <= 31
		super().__setitem__(key, value)


class FakeService:
	def __init__(self, mode, target):
		self.values = {"/Values/HeatingMode": mode, "/Values/HeatingTargetTemp": target}

	def get_value(self, path):
		return self.values.get(path)

	def set_value(self, path, value):
		self.values[path] = value


class FakeApp:
	def __init__(self):
		self.commands = []

	def set_status(self, name, value):
		self.commands.append((name, value))


class HeatingControllerTests(unittest.TestCase):
	def setUp(self):
		self.controller = InetboxController.__new__(InetboxController)
		self.controller.log = logging.getLogger("inetbox-controller-test")
		self.controller._settings = FakeSettings({"/LastHeatingTemp": 19})
		self.controller._dbusInetboxService = FakeService("off", 20)
		self.controller._app = FakeApp()

	def test_zero_turns_heating_off_without_overwriting_saved_temperature(self):
		for value in (0, "0", "0.0"):
			with self.subTest(value=value):
				self.controller._dbusInetboxService.values["/Values/HeatingTargetTemp"] = 20
				self.assertTrue(self.controller.dbus_value_to_inetbox("/Values/HeatingTargetTemp", value))
				self.assertEqual(self.controller._settings["/LastHeatingTemp"], 19)
				self.assertEqual(self.controller._app.commands[-1], ("target_temp_room", value))

	def test_off_mode_saves_valid_integer_targets(self):
		for value, expected in ((4, 4), ("20.0", 20), (31, 31)):
			with self.subTest(value=value):
				self.assertTrue(self.controller.dbus_value_to_inetbox("/Values/HeatingTargetTemp", value))
				self.assertEqual(self.controller._settings["/LastHeatingTemp"], expected)

	def test_invalid_off_mode_target_is_rejected_before_command(self):
		for value in (1, 32, "20.5", "invalid", None, float("nan")):
			with self.subTest(value=value), self.assertLogs("inetbox-controller-test", level="WARNING"):
				self.assertFalse(self.controller.dbus_value_to_inetbox("/Values/HeatingTargetTemp", value))
				self.assertEqual(self.controller._settings["/LastHeatingTemp"], 19)
				self.assertEqual(self.controller._app.commands, [])

	def test_off_then_on_restores_the_last_target(self):
		self.controller._dbusInetboxService.values["/Values/HeatingMode"] = "eco"
		self.controller._dbusInetboxService.values["/Values/HeatingTargetTemp"] = "21.0"
		self.assertTrue(self.controller.dbus_value_to_inetbox("/Values/HeatingMode", "off"))
		self.assertEqual(self.controller._settings["/LastHeatingTemp"], 21)
		self.assertEqual(self.controller._app.commands[-1], ("target_temp_room", 0))
		self.assertEqual(self.controller._dbusInetboxService.get_value("/Values/HeatingTargetTemp"), 0)
		self.controller.inetbox_value_to_dbus("target_temp_room", "0")
		self.assertEqual(self.controller._dbusInetboxService.get_value("/Values/HeatingTargetTemp"), "0")
		self.assertEqual(self.controller._settings["/LastHeatingTemp"], 21)
		self.assertTrue(self.controller.dbus_value_to_inetbox("/Values/HeatingMode", "eco"))
		self.assertEqual(self.controller._app.commands[-1], ("target_temp_room", 21))
		self.assertEqual(self.controller._dbusInetboxService.get_value("/Values/HeatingTargetTemp"), 21)

	def test_off_with_unknown_target_preserves_saved_temperature(self):
		self.controller._dbusInetboxService.values["/Values/HeatingMode"] = "eco"
		self.controller._dbusInetboxService.values["/Values/HeatingTargetTemp"] = None
		with self.assertLogs("inetbox-controller-test", level="WARNING"):
			self.assertTrue(self.controller.dbus_value_to_inetbox("/Values/HeatingMode", "off"))
		self.assertEqual(self.controller._settings["/LastHeatingTemp"], 19)
		self.assertEqual(self.controller._app.commands[-1], ("target_temp_room", 0))

	def test_lin_zero_target_remains_zero(self):
		for value in ("0", 0, "0.0"):
			with self.subTest(value=value):
				self.controller.inetbox_value_to_dbus("target_temp_room", value)
				self.assertEqual(self.controller._dbusInetboxService.get_value("/Values/HeatingTargetTemp"), value)
				self.assertEqual(self.controller._settings["/LastHeatingTemp"], 19)

	def test_off_schedule_does_not_restore_scheduled_target(self):
		self.controller._dbusInetboxService.values["/Values/HeatingMode"] = "eco"
		schedules_class = load_schedules()
		scheduler = schedules_class.__new__(schedules_class)
		scheduler._log = logging.getLogger("inetbox-controller-test")
		scheduler._is_due = lambda _path, _minute: True
		scheduler._read_value = lambda _path, key: {"HeatingMode": "off", "HeatingTargetTemp": 24}[key]
		scheduler._apply_callback = self.controller.dbus_value_to_inetbox
		scheduler._disable_if_one_shot = Mock()
		scheduler._run_heating_schedule(0)
		self.assertEqual(self.controller._dbusInetboxService.get_value("/Values/HeatingTargetTemp"), 0)
		self.assertEqual(self.controller._app.commands, [("heating_mode", "off"), ("target_temp_room", 0)])


if __name__ == "__main__":
	unittest.main()
