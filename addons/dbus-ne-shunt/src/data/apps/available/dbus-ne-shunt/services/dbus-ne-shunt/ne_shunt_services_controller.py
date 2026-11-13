import sys
import os
import logging
from typing import Optional

sys.path.append(os.path.join(os.path.dirname(__file__), 'ext'))
sys.path.append(os.path.join(os.path.dirname(__file__), 'serial_service'))
sys.path.append(os.path.join(os.path.dirname(__file__), 'dbus_services'))

from dbus_services.switch_service import switch_service
from dbus_services.tank_service import tank_service
from dbus_services.battery_service import battery_service
from dbus_services.dbus_constants import dbus_constants
from dbus_services.dbus_connection import dbusconnection
from ext.settingsdevice import SettingsDevice  # available in the velib_python repository

from serial_service.ne_shunt_serial_service import ne_shunt_serial_service
from serial_service.ne_shunt_data import ne_shunt_data

############################################
# manages the reading and writing of data
# between the dbus and the serial device (ne-shunt)
############################################
class ne_shunt_services_controller:

	_serialService : Optional[ne_shunt_serial_service] = None
	_services : dict = dict()
	_settings : SettingsDevice
	_curData : Optional[ne_shunt_data] = None
	_serial_port : str
	_inUpdate = False
	_settingsPath = None
	_lastData : str = ""
	_reset = False
	_readonly = False
	_cancelled = False
	_sid : str

	############################################
	# constructor
	# serial port is passed from the SerialStarter
	# service. i.e. /dev/ttyACM0
	############################################
	def __init__(self, serialPort, sid, readonly):
		self._serial_port = serialPort
		self._sid = sid
		self._readonly = readonly

	############################################
	# initial setup of services and settings
	############################################
	def initialize(self):

		self._initializeSettings()
		self._start_stop_services()


	def close(self):
		self._cancelled = True

	############################################
	# Starts and stops the serial service as
	# required
	############################################
	def _start_stop_serial_service(self):
		logging.debug('_start_stop_serial_service')

		#state 0 (nothing running ... close)
		if (self._serialService and len(self._services) == 0):
			self._serialService.close()
			self._serialService = None

		if (self._serialService == None and len(self._services) > 0):
			self._serialService = ne_shunt_serial_service(self._serial_port, self._readonly)

	# ############################################
	# # Occurs when the a device setting value is
	# # changed such as ShowControls
	# ############################################
	def _handle_changed_setting(self, setting, oldvalue, newvalue):
		logging.info('setting changed, setting: %s, old: %s, new: %s' % (setting, oldvalue, newvalue))
		if (setting == "/SwitchableOutput/FreshWaterTank/State"):
			self._start_stop_services(setting, newvalue)
		return True

	def _dbus_tank_value_changed(self, name, path, newvalue):
		logging.info(f"_dbus_tank_value_changed:{name}, {path}, {newvalue}")
		self._settings[f"/{name}{path}"] = newvalue
		return True

	############################################
	# Occurs when a switch is toggled in the UI
	############################################
	def _dbus_switch_value_changed(self, name, path, newvalue):

		logging.info('switch dbus value changed, name: %s, path: %s, newvalue: %s' % (name, path, newvalue))

		if (path.endswith('/CustomName') or path.endswith('/Group') or path.endswith('/ShowUIControl')):
			self._settings[path] = newvalue
		elif (path == '/SwitchableOutput/ExternalLights/State'):
			self._try_toggle_serial_switch_value("external_lights", path, newvalue)
		elif (path == "/SwitchableOutput/InternalLights/State"):
			self._try_toggle_serial_switch_value("internal_lights", path, newvalue)
		elif (path == "/SwitchableOutput/WaterPump/State" ):
			self._try_toggle_serial_switch_value("water_pump", path, newvalue)
		elif (path == "/SwitchableOutput/Aux/State" ):
			self._try_toggle_serial_switch_value("aux", path, newvalue)
		elif (path == "/SwitchableOutput/FreshWaterTank/State"):
			self._settings[path] = newvalue
			self._start_stop_services('FreshWaterTank', newvalue)
		elif (path == "/SwitchableOutput/GreyWasteTank/State"):
			self._settings[path] = newvalue
			self._start_stop_services('GreyWasteTank', newvalue)
		elif (path == "/SwitchableOutput/GreyWasteTank2/State"):
			self._settings[path] = newvalue
			self._start_stop_services('GreyWasteTank2', newvalue)
		elif (path == "/SwitchableOutput/LeisureBattery/State"):
			self._settings[path] = newvalue
			self._start_stop_services('LeisureBattery', newvalue)
		elif (path == "/SwitchableOutput/VehicleBattery/State"):
			self._settings[path] = newvalue
			self._start_stop_services('VehicleBattery', newvalue)
		else:
			return False
		return True

	############################################
	# Occurs when a battery value has changed the UI
	############################################
	def _dbus_battery_value_changed(self, name, path, newvalue):
		if path == '/CustomName':
			self._settings[f"/{name}{path}"] = newvalue
			return True

		service = self._services.get(name, None)
		if service is None:
			return False

		if path == '/MinVoltage':
			service.MinVoltage = newvalue
		elif path == '/MaxVoltage':
			service.MaxVoltage = newvalue
		else:
			return False

		self._settings[f"/{name}{path}"] = newvalue
		return True

	############################################
	# if the value recieved has changed it
	# sends the toggle switch serial message to
	# the pysical device
	############################################
	def _try_toggle_serial_switch_value(self, name, service_path, newvalue):

		service = self._services.get("switches", None)
		if (self._serialService == None ):
			logging.debug('_try_toggle_serial_switch_value: serial service=None')
			return False

		if (service is None or self._curData == None):
			logging.debug('_try_toggle_serial_switch_value: service=None')
			return False

		if ( self._curData == None):
			logging.debug('_try_toggle_serial_switch_value: serial data=None')
			return False

		if not (newvalue == 1 or newvalue == 0):
			logging.debug('_try_toggle_serial_switch_value: invalid value. value must be 0 or 1 for ' + name)
			return False

		curValue = self._curData.get_value(name)
		if (curValue != newvalue):
			return self._serialService.toggle_switch(name)

		return False

	def _get_vrm_class_instance(self, key):
		# value format is "<class>:<instance>"
		return int(str(self._settings[f'/{key}/ClassAndVrmInstance']).split(':')[1])


	############################################
	# starts and stops the dbus tank service
	# There can be upto 3 three tanks.
	# FreshWater, GreyWaste1 and GreyWaste2
	############################################
	def _start_stop_tank_service(self, name, fluid_type, enabled = None):
		logging.debug(f"_start_stop_tank_service: {name}")
		service = self._services.get(name, None)

		# '/SwitchableOutput/FreshWaterTank/State'

		if (enabled is None):
			enabled = int(self._settings[f"/SwitchableOutput/{name}/State"])

		if (enabled == 1):
			if (service is None):
				logging.debug(f"_start_stop_tank_service: {name} creating")

				device_instance = self._get_vrm_class_instance(name)
				dbus_service_name = switch_service.serviceNameBuilder(
						dbus_constants.SERVICE_TYPE_TANK, f"neshunt_{device_instance}_sid_{self._sid}")

				custome_name = str(self._settings[f"/{name}/CustomName"])
				service = tank_service(custome_name, self._serial_port, name, dbus_service_name, device_instance,
					fluid_type, 1.0, self._dbus_tank_value_changed)

				self._services[name] = service
			else:
				logging.debug(f"_start_stop_tank_service: {name} already running")
		elif (service):
			logging.debug(f"_start_stop_tank_service: {name} removing")
			self._services.pop(name)
			service.unregister()

		switches_service = self._services.get("switches", None)
		if (switches_service):
			switches_service.set_switch_status(f"/SwitchableOutput/{name}/Status", enabled)

	############################################
	# starts and stops the dbus switch service
	# The nord electornics 194 has 4 service
	# switches. Aux, Water Pump, Internal Lights &
	# External Lights
	############################################
	def _start_stop_switch_service(self):
		logging.debug("_start_stop_switch_service in")

		dbus_name = 'Switches'
		service = self._services.get("switches", None)
		if service:
			logging.debug("_start_stop_switch_service: unregister")
			service.unregister()
			service = None
			self._services.pop("switches")
			return
		else:
			logging.debug("_start_stop_switch_service: starting")

		switches = ["Internal Lights", "External Lights", "Water Pump", "Aux", "FreshWaterTank", "GreyWasteTank",
			"GreyWasteTank2", "LeisureBattery", "VehicleBattery"]

		custome_name = str(self._settings[f"/{dbus_name}/CustomName"])
		device_instance = self._get_vrm_class_instance(dbus_name)
		dbus_service_name = switch_service.serviceNameBuilder(
				dbus_constants.SERVICE_TYPE_SWITCH, f"neshunt_{device_instance}_sid_{self._sid}")

		service = switch_service(self._settings, self._sid,
										custome_name,
										self._serial_port,
										dbus_name,
										dbus_service_name,
										device_instance,
										switches,
										onValueChangedCallback = self._dbus_switch_value_changed)

		self._services["switches"] = service

	############################################
	# Starts the dbus vehicle battery service
	# the ne shunt also has a leisure battery
	# but this is not likely needed in Victron
	# setup
	############################################
	def _start_stop_battery_service(self, name, enabled = None):

		logging.debug("_start_stop_battery_service in")

		service = self._services.get(name, None)

		if (enabled is None):
			enabled = int(self._settings[f"/SwitchableOutput/{name}/State"])

		if (enabled == 1):
			if (service is None):

				device_instance = self._get_vrm_class_instance(name)
				dbus_service_name = battery_service.serviceNameBuilder(
						dbus_constants.SERVICE_TYPE_BATTERY, f"neshunt_{device_instance}_sid_{self._sid}")

				custom_name = str(self._settings[f"/{name}/CustomName"])
				service = battery_service(
							custom_name,
							self._serial_port,
							name,
							dbus_service_name,
							device_instance,
							capacity = 0,
							onValueChangedCallback = self._dbus_battery_value_changed)
				self._services[name] = service
			else:
				logging.debug(f"_start_stop_tank_service: {name} already running")

		elif (service):
			logging.debug(f"_start_stop_tank_service: {name} removing")
			self._services.pop(name)
			service.unregister()

		switches_service = self._services.get("switches", None)
		if (switches_service):
			switches_service.set_switch_status(f"/SwitchableOutput/{name}/Status", enabled)

	############################################
	# starts and stops all services
	############################################
	def _start_stop_services(self, name = None, newValue = None):

		if (name is None or name == 'FreshWaterTank'):
			self._start_stop_tank_service('FreshWaterTank', dbus_constants.FLUID_TYPE_FRESH_WATER, newValue)

		if (name is None or name == 'GreyWasteTank'):
			self._start_stop_tank_service('GreyWasteTank', dbus_constants.FLUID_TYPE_WASTE_WATER, newValue)

		if (name is None or name == 'GreyWasteTank2'):
			self._start_stop_tank_service('GreyWasteTank2', dbus_constants.FLUID_TYPE_WASTE_WATER, newValue)

		if (name is None or name == 'VehicleBattery'):
			self._start_stop_battery_service('VehicleBattery', newValue)

		if (name is None or name == 'LeisureBattery'):
			self._start_stop_battery_service('LeisureBattery', newValue)

		if (name is None or name == 'Switches'):
			self._start_stop_switch_service()

		# start stop the serial service as required.
		self._start_stop_serial_service()

	############################################
	# updates a dbus service value from the
	# passed physical device value
	############################################
	def update_dbus_item(self, serviceName, servicePath, newValue):
		logging.debug("update_dbus_item in")

		dbus_service = self._services.get(serviceName, None)
		if dbus_service:
			logging.debug(f"update_dbus_item set_value: {servicePath}/newValue = {newValue}")
			dbus_service.set_value(servicePath, newValue)
			if serviceName == "switches" and servicePath.endswith("/State"):
				status_path = servicePath.removesuffix("/State") + "/Status"
				dbus_service.set_switch_status(status_path, newValue)

		else:
			logging.debug(f"update_dbus_item: serviceName = None ({serviceName})" )

		logging.debug("update_dbus_item out")


	############################################
	# reads the 485 serial data from from the
	# ne-shunt and passes any changed values
	# to the dbus
	# returns True to continue
	# calling code should call this code continualy
	# for example: GLib.timeout_add(1000, nuss._update)
	############################################
	def _update(self):
		if self._cancelled:
			return False

		if (self._serialService == None):
			logging.debug("_update out ss=None")
			return True

		logging.debug("read_data in")
		data = self._serialService.read_data()
		if not data:
			logging.debug("_update out: no data returned")
			return True

		if self._cancelled:
			return False

		if (data == self._lastData):
			logging.debug("no change exiting...")
			return True

		#logging.debug(f"data: {data}\n_lastData:{self._lastData}")

		newData = ne_shunt_data(data)
		#copy curData so we can update _curData and we don't get
		# recursive updates from update_item
		curData = self._curData.clone() if self._curData else None

		for key, value in newData.diff(curData):

			logging.debug(f"value changed: {key} = {value}")

			match key:
				case 'fresh_water_tank' | 'grey_waste_tank' | 'grey_waste_tank2':
					service_name = {
						'fresh_water_tank': 'FreshWaterTank',
						'grey_waste_tank': 'GreyWasteTank',
						'grey_waste_tank2': 'GreyWasteTank2',
					}[key]
					self.update_dbus_item(service_name, "/Level", value)
				case 'external_lights':
					self.update_dbus_item("switches", "/SwitchableOutput/ExternalLights/State", value)
				case 'internal_lights':
					self.update_dbus_item("switches", "/SwitchableOutput/InternalLights/State", value)
				case 'water_pump':
					self.update_dbus_item("switches", "/SwitchableOutput/WaterPump/State", value)
				case 'aux':
					self.update_dbus_item("switches", "/SwitchableOutput/Aux/State", value)
				case 'vehicle_battery' | 'leisure_battery':
					service_name = {'vehicle_battery': 'VehicleBattery', 'leisure_battery': 'LeisureBattery'}[key]
					self.update_dbus_item(service_name, "/Voltage", value)
					dbus_service = self._services.get(service_name, None)
					if dbus_service:
						self.update_dbus_item(service_name, "/Soc", dbus_service.calcBatterySoc(value))

		 #keep at end, helps dbus events from turning off values before we are populated
		self._curData = newData
		self._lastData = data

		return True


	############################################
	# Initializes the dbus device settings
	# Needs custom UI
	############################################
	def _initializeSettings(self):

		settingsPath = f'/Settings/Devices/sid_{self._sid}'

		logging.info("Initializing settings: %s", settingsPath)

		# unique path used to generate unique ClassAndVrmInstance value
		# see https://github.com/victronenergy/localsettings#using-addsetting-to-allocate-a-vrm-device-instance

		# NOTE for ClassAndVrmInstance the paths are:
		# /Settings/Devices/sid_1234_FreshWaterTank/ClassAndVrmInstance
		# /Settings/Devices/sid_1234_GreyWasteTank/ClassAndVrmInstance
		# /Settings/Devices/sid_1234_FreshWaterTank2/ClassAndVrmInstance
		# Doing the following does not work
		# /Settings/Devices/sid_1234/FreshWaterTank/ClassAndVrmInstance
		# /Settings/Devices/sid_1234/FreshWaterTank2/ClassAndVrmInstance

		def _add_switch_settings(name, custom_name, group, visible, value):
			return {f'/SwitchableOutput/{name}/Settings/CustomName' : [f'{settingsPath}/Switches/{name}/CustomName', custom_name, "", ""],
			f'/SwitchableOutput/{name}/Settings/Group' : [f'{settingsPath}/Switches/{name}/Group', group, "", ""],
			f'/SwitchableOutput/{name}/Settings/ShowUIControl' : [f'{settingsPath}/Switches/{name}/ShowUIControl', visible, 0, 1],
			f'/SwitchableOutput/{name}/State' : [f'{settingsPath}/Switches/{name}/State', value, 0, 1]
			}

		supportedSettings = {

			'/Sid': [f'{settingsPath}/Sid', self._sid, 0, 0],
			'/Sid2' : [f'{settingsPath}/Sid2', self._sid, 0, 0],
			'/ProductName' : [f'{settingsPath}/ProductName', dbus_constants.PRODUCT_NAME, "", ""],
			'/DeviceKey' : [f'{settingsPath}/DeviceKey', dbus_constants.DEVICE_KEY, 0, 0],

			# ClassAndVrmInstance
			'/Switches/ClassAndVrmInstance' : [f'{settingsPath}_Switches/ClassAndVrmInstance',
									f"{dbus_constants.SERVICE_TYPE_SWITCH}:{dbus_constants.DEFAULT_DEVICE_INSTANCE}", 0, 0],
			'/FreshWaterTank/ClassAndVrmInstance' : [f'{settingsPath}_FreshWaterTank/ClassAndVrmInstance',
									f"{dbus_constants.SERVICE_TYPE_TANK}:{dbus_constants.DEFAULT_DEVICE_INSTANCE}", 0, 0],
			'/GreyWasteTank/ClassAndVrmInstance' : [f'{settingsPath}_GreyWasteTank/ClassAndVrmInstance',
									f"{dbus_constants.SERVICE_TYPE_TANK}:{dbus_constants.DEFAULT_DEVICE_INSTANCE}", 0, 0],
			'/GreyWasteTank2/ClassAndVrmInstance' : [f'{settingsPath}_GreyWasteTank2/ClassAndVrmInstance',
									f"{dbus_constants.SERVICE_TYPE_TANK}:{dbus_constants.DEFAULT_DEVICE_INSTANCE}", 0, 0],
			'/VehicleBattery/ClassAndVrmInstance' : [f'{settingsPath}_CabBattery/ClassAndVrmInstance',
									f"{dbus_constants.SERVICE_TYPE_BATTERY}:{dbus_constants.DEFAULT_DEVICE_INSTANCE}", 0, 0],
			'/LeisureBattery/ClassAndVrmInstance' : [f'{settingsPath}_LeisureBattery/ClassAndVrmInstance',
									f"{dbus_constants.SERVICE_TYPE_BATTERY}:{dbus_constants.DEFAULT_DEVICE_INSTANCE}", 0, 0],

			'/Switches/CustomName' : [f'{settingsPath}/Switches/CustomName', "NeShunt switches", "", ""],
			'/VehicleBattery/CustomName' : [f'{settingsPath}/VehicleBattery/CustomName', "NeShunt vehicle battery", "", ""],
			'/LeisureBattery/CustomName' : [f'{settingsPath}/LeisureBattery/CustomName', "NeShunt leisure battery", "", ""],
			'/FreshWaterTank/CustomName' : [f'{settingsPath}/FreshWaterTank/CustomName', "NeShunt fresh water tank", "", ""],
			'/GreyWasteTank/CustomName' : [f'{settingsPath}/GreyWasteTank/CustomName', "NeShunt grey waste tank", "", ""],
			'/GreyWasteTank2/CustomName' : [f'{settingsPath}/GreyWasteTank2/CustomName', "NeShunt grey waste tank 2", "", ""],

			# Battery
			# TODO add input controls for min/max (4 controls)

			'/VehicleBattery/MinVoltage' : [f'{settingsPath}/VehicleBattery/MinVoltage', 0, 0, 24],
			'/VehicleBattery/MaxVoltage' : [f'{settingsPath}/VehicleBattery/MaxVoltage', 0, 0, 24],

			'/LeisureBattery/MinVoltage' : [f'{settingsPath}/LeisureBattery/MinVoltage', 0, 0, 24],
			'/LeisureBattery/MaxVoltage' : [f'{settingsPath}/LeisureBattery/MaxVoltage', 0, 0, 24],

			# CustomName
			'/CustomName' : [f'{settingsPath}/CustomName', "", "", ""],

		}

		supportedSettings.update(_add_switch_settings("InternalLights", "Internal lights", "", 1, 1))
		supportedSettings.update(_add_switch_settings("ExternalLights", "External lights", "", 1, 0))
		supportedSettings.update(_add_switch_settings("WaterPump", "Water pump", "", 1, 1))
		supportedSettings.update(_add_switch_settings("Aux","Aux", "", 1, 1))

		supportedSettings.update(_add_switch_settings("FreshWaterTank", "Enable fresh water tank service", "", 1, 1))
		supportedSettings.update(_add_switch_settings("GreyWasteTank", "Enable grey waste tank service", "", 1, 1))
		supportedSettings.update(_add_switch_settings("GreyWasteTank2", "Enable grey waste tank 2 service", "", 0, 0))
		supportedSettings.update(_add_switch_settings("LeisureBattery", "Enable leisure battery service", "", 0, 0))
		supportedSettings.update(_add_switch_settings("VehicleBattery", "Enable vehicle battery service", "", 1, 1))

		self._settings = SettingsDevice(
			bus = dbusconnection(),
			supportedSettings=supportedSettings,
			eventCallback = None)
			# eventCallback = self._handle_changed_setting)
