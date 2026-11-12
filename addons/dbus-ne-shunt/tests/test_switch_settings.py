import importlib
from pathlib import Path
import sys
import types
import unittest
from unittest.mock import patch


SERVICE_DIR = (Path(__file__).resolve().parents[1] / "src/data/apps/available/"
               "dbus-ne-shunt/services/dbus-ne-shunt")


class FakeSettingsDevice:
	def __init__(self, bus, supportedSettings, eventCallback):
		self.definitions = supportedSettings
		self.values = {key: options[1] for key, options in supportedSettings.items()}

	def __getitem__(self, key):
		return self.values[key]

	def __setitem__(self, key, value):
		if key not in self.values:
			raise KeyError(key)
		self.values[key] = value


class FakeBaseService:
	@staticmethod
	def serviceNameBuilder(className, serviceIdentifier):
		return f"com.victronenergy.{className}.{serviceIdentifier}"

	def _registerCore(self, connection, deviceInstance, name, serviceName,
					  productId, productName, firmwareVersion, hardwareVersion,
					  paths, onValueChanged=None):
		self.paths = paths
		self.callback = onValueChanged
		self.unregistered = False

	def unregister(self):
		self.unregistered = True

	def set_value(self, path, value):
		self.paths[path]["initial"] = value

	def get_value(self, path):
		return self.paths[path]["initial"]


class FakeSerialService:
	def __init__(self, port, readonly):
		pass

	def close(self):
		pass


def module(name, **attributes):
	result = types.ModuleType(name)
	for key, value in attributes.items():
		setattr(result, key, value)
	return result


class SwitchSettingsTests(unittest.TestCase):
	@classmethod
	def setUpClass(cls):
		cls.path_patch = patch.object(sys, "path", [str(SERVICE_DIR)] + sys.path)
		cls.path_patch.start()
		cls.module_patch = patch.dict(sys.modules, {
			"dbus_base_service": module("dbus_base_service", dbus_base_service=FakeBaseService),
			"dbus_services.dbus_connection": module("dbus_services.dbus_connection", dbusconnection=lambda: object()),
			"ext.settingsdevice": module("ext.settingsdevice", SettingsDevice=FakeSettingsDevice),
			"serial_service.ne_shunt_serial_service": module(
				"serial_service.ne_shunt_serial_service", ne_shunt_serial_service=FakeSerialService),
			"serial_service.ne_shunt_data": module("serial_service.ne_shunt_data", ne_shunt_data=object),
		})
		cls.module_patch.start()
		cls.controller_class = importlib.import_module("ne_shunt_services_controller").ne_shunt_services_controller

	@classmethod
	def tearDownClass(cls):
		cls.module_patch.stop()
		cls.path_patch.stop()

	def setUp(self):
		self.controller = self.controller_class("/dev/ttyTEST", "123", False)
		self.controller.initialize()

	def test_all_switch_settings_are_registered_and_published(self):
		expected = {
			"InternalLights": ("Internal lights", 1, 1),
			"ExternalLights": ("External lights", 1, 0),
			"WaterPump": ("Water pump", 1, 1),
			"Aux": ("Aux", 1, 1),
			"FreshWaterTank": ("Enable fresh water tank service", 1, 1),
			"GreyWasteTank": ("Enable grey waste tank service", 1, 1),
			"GreyWasteTank2": ("Enable grey waste tank 2 service", 0, 0),
			"LeisureBattery": ("Enable leisure battery service", 0, 0),
			"VehicleBattery": ("Enable vehicle battery service", 1, 1),
		}
		service = self.controller._services["switches"]
		for name, (custom_name, visible, state) in expected.items():
			for suffix, value, limits in (
				("Settings/CustomName", custom_name, ("", "")),
				("Settings/Group", "", ("", "")),
				("Settings/ShowUIControl", visible, (0, 1)),
				("State", state, (0, 1)),
			):
				with self.subTest(name=name, suffix=suffix):
					key = f"/SwitchableOutput/{name}/{suffix}"
					leaf = suffix.split("/")[-1]
					self.assertEqual(
						self.controller._settings.definitions[key],
						[f"/Settings/Devices/sid_123/Switches/{name}/{leaf}", value, *limits],
					)
					self.assertEqual(service.paths[key]["initial"], value)
					self.assertTrue(service.paths[key]["writable"])

	def test_battery_switches_start_and_stop_services(self):
		self.assertIn("VehicleBattery", self.controller._services)
		self.assertNotIn("LeisureBattery", self.controller._services)
		for name in ("LeisureBattery", "VehicleBattery"):
			path = f"/SwitchableOutput/{name}/State"
			self.assertTrue(self.controller._dbus_switch_value_changed("Switches", path, 1))
			service = self.controller._services[name]
			self.assertEqual(self.controller._settings[path], 1)
			status = self.controller._services["switches"].paths[f"/SwitchableOutput/{name}/Status"]
			self.assertEqual(status["initial"], 0x09)
			self.assertTrue(self.controller._dbus_switch_value_changed("Switches", path, 0))
			self.assertTrue(service.unregistered)
			self.assertNotIn(name, self.controller._services)
			self.assertEqual(self.controller._settings[path], 0)
			self.assertEqual(status["initial"], 0x00)

	def test_battery_settings_are_writable(self):
		controller = self.controller
		self.assertTrue(controller._dbus_battery_value_changed("VehicleBattery", "/CustomName", "Cab"))
		self.assertEqual(controller._settings["/VehicleBattery/CustomName"], "Cab")
		self.assertTrue(controller._dbus_battery_value_changed("VehicleBattery", "/MinVoltage", 12.0))
		self.assertEqual(controller._settings["/VehicleBattery/MinVoltage"], 12.0)
		self.assertEqual(controller._services["VehicleBattery"].MinVoltage, 12.0)
		self.assertFalse(controller._dbus_battery_value_changed("LeisureBattery", "/MinVoltage", 12.0))

	def test_tank_switch_starts_and_stops_service(self):
		path = "/SwitchableOutput/GreyWasteTank2/State"
		self.assertNotIn("GreyWasteTank2", self.controller._services)
		self.assertTrue(self.controller._dbus_switch_value_changed("Switches", path, 1))
		service = self.controller._services["GreyWasteTank2"]
		status = self.controller._services["switches"].paths["/SwitchableOutput/GreyWasteTank2/Status"]
		self.assertEqual(status["initial"], 0x09)
		self.assertTrue(self.controller._dbus_switch_value_changed("Switches", path, 0))
		self.assertTrue(service.unregistered)
		self.assertNotIn("GreyWasteTank2", self.controller._services)
		self.assertEqual(status["initial"], 0x00)

	def test_physical_switch_updates_state_and_status(self):
		service = self.controller._services["switches"]
		path = "/SwitchableOutput/ExternalLights"
		for value, status in ((1, 0x09), (0, 0x00)):
			self.controller.update_dbus_item("switches", path + "/State", value)
			self.assertEqual(service.paths[path + "/State"]["initial"], value)
			self.assertEqual(service.paths[path + "/Status"]["initial"], status)
		self.assertEqual(service.ShowUIControl("ExternalLights"), 1)

	def test_serial_updates_reach_enabled_tank_and_battery_services(self):
		controller = self.controller
		controller._serialService.read_data = lambda: "serial data"
		data = types.SimpleNamespace(diff=lambda previous: [
			("fresh_water_tank", 42),
			("vehicle_battery", 12.0),
		])
		with patch.object(sys.modules["ne_shunt_services_controller"], "ne_shunt_data", return_value=data):
			self.assertTrue(controller._update())
		self.assertEqual(controller._services["FreshWaterTank"].paths["/Level"]["initial"], 42)
		battery = controller._services["VehicleBattery"]
		self.assertEqual(battery.paths["/Voltage"]["initial"], 12.0)
		self.assertAlmostEqual(battery.paths["/Soc"]["initial"], battery.calcBatterySoc(12.0))

	def test_restarting_switch_service_unregisters_previous_instance(self):
		old_service = self.controller._services["switches"]
		self.controller._start_stop_services("Switch")
		self.assertTrue(old_service.unregistered)
		self.assertIsNot(old_service, self.controller._services["switches"])


if __name__ == "__main__":
	unittest.main()
