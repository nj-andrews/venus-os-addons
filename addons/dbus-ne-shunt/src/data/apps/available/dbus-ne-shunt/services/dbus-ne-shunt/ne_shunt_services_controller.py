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

		self._services = dict()
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

		#state 0 (nothing running ... so close)
		if (self._serialService and len(self._services) == 0):
			self._serialService.close()
			self._serialService = None

		if (self._serialService == None and len(self._services) > 0):
			self._serialService = ne_shunt_serial_service(self._serial_port, self._readonly)

	############################################
	# Occurs when the a device setting value is
	# changed such as ShowControls
	############################################
	def _handle_changed_setting(self, setting, oldvalue, newvalue):
		logging.debug('setting changed, setting: %s, old: %s, new: %s' % (setting, oldvalue, newvalue))

		self._start_stop_services(setting, newvalue)
		return True

	def _dbus_tank_value_changed(self, name, path, newvalue):
		logging.debug(f"_dbus_tank_value_changed:{name}, {path}, {newvalue}")
		self._settings[f"/{name}{path}"] = newvalue
		return True

	############################################
	# Occurs when a switch is toggled in the UI
	############################################
	def _dbus_switch_value_changed(self, name, path, newvalue):

		logging.debug('switch dbus value changed, name: %s, path: %s, newvalue: %s' % (name, path, newvalue))

		if (path.endswith('/CustomName') or path.endswith('/Group') or path.endswith('/ShowUIControl')):
			self._settings[path] = newvalue
		elif (path == '/SwitchableOutput/ExternalLights/State'):
			self._try_toggle_serial_switch_value("external_lights", newvalue)
		elif (path == "/SwitchableOutput/InternalLights/State"):
			self._try_toggle_serial_switch_value("internal_lights", newvalue)
		elif (path == "/SwitchableOutput/WaterPump/State" ):
			self._try_toggle_serial_switch_value("water_pump", newvalue)
		elif (path == "/SwitchableOutput/Aux/State" ):
			self._try_toggle_serial_switch_value("aux", newvalue)

		else:
			return False
		return True

	############################################
	# Occurs when a battery value has changed the UI
	############################################
	def _dbus_battery_value_changed(self, name, path, newvalue):
		if path == '/CustomName':
			self._settings[f"{name}/{path}"]=newvalue
			return

		service = self._services.get(name, None)
		if (service == none): return

		if path == '/MinVoltage':
			service.MinVoltage = newvalue
		elif path == '/MaxVoltage':
			service.MaxVoltage = newvalue
		else:
			return

		self._settings[f"{name}/{path}"] = newvalue

	############################################
	# if the value recieved has changed it
	# sends the toggle switch serial message to
	# the pysical device
	############################################
	def _try_toggle_serial_switch_value(self, name, newvalue):

		if (self._serialService == None or self._curData == None):
			logging.debug('_try_toggle_serial_switch_value: serial service or curData is None')
			return False

		if not (newvalue == 1 or newvalue == 0):
			logging.debug('_try_toggle_serial_switch_value: invalid value. value must be 0 or 1 for ' + name)
			return False

		curValue = self._curData.get_value(name)

		if (curValue != newvalue):
			return self._serialService.toggle_switch(name)

		return False

	def _get_device_instance(self, key):
		# value format is "<class>:<instance>"
		return int(str(self._settings[f'/{key}/ClassAndVrmInstance']).split(':')[1])

	############################################
	# starts and stops the dbus tank service
	# There can be upto 3 three tanks.
	# FreshWater, GreyWaste1 and GreyWaste2
	############################################
	def _start_stop_tank_service(self, name, fluid_type):
		logging.debug(f"_start_stop_tank_service: {name}")
		service = self._services.get(name, None)

		custome_name = str(self._settings[f"/{name}/CustomName"])
		display = int(self._settings[f"/{name}/Display"])

		if (display == 1):
			if (service is None):
				logging.debug(f"_start_stop_tank_service: {name} creating")

				device_instance = self._get_device_instance(name)
				dbus_service_name = switch_service.serviceNameBuilder(
						dbus_constants.SERVICE_TYPE_TANK, f"neshunt_{device_instance}_sid_{self._sid}")

				service = tank_service(custome_name, self._serial_port, name, dbus_service_name, device_instance, fluid_type, 1.0,
					self._dbus_tank_value_changed)

				self._services[name] = service
			else:
				logging.debug(f"_start_stop_tank_service: {name} already running")
		elif (service):
			logging.debug(f"_start_stop_tank_service: {name} removing")
			self._services.pop(name)
			service.unregister()

	############################################
	# starts and stops the dbus switch service
	# The nord electornics 194 has 4 service
	# switches. Aux, Water Pump, Internal Lights &
	# External Lights
	############################################
	def _start_stop_switch_service(self):
		logging.debug("_start_stop_switch_service in")

		name = 'Switches'
		service = self._services.get(name, None)
		if service:
			logging.debug("_start_stop_switch_service: unregister")
			service.unregister()
			service = None
			self._services.pop(name)
		else:
			logging.debug("_start_stop_switch_service: Not running")

		switches = ["Internal Lights", "External Lights", "Water Pump", "Aux"]
		custome_name = "Ne-Shunt switches" #str(self._settings[f"/{name}/CustomName"])
		device_instance = self._get_device_instance(name)
		dbus_service_name = switch_service.serviceNameBuilder(
				dbus_constants.SERVICE_TYPE_SWITCH, f"neshunt_{device_instance}_sid_{self._sid}")

		self._services["switches"] = switch_service(self._settings, self._sid,
										custome_name,
										self._serial_port,
										name,
										dbus_service_name,
										device_instance,
										switches,
										onValueChangedCallback = self._dbus_switch_value_changed)

	############################################
	# Starts the dbus vehicle battery service
	# the ne shunt also has a leisure battery
	# but this is not likely needed in Victron
	# setup
	############################################
	def _start_battery_services(self):

		logging.debug("_start_battery_services in")

		def _start_battery_service(name, custom_name):
			service = self._services.get(name, None)
			if (service == None):
				device_instance = self._get_device_instance(name)
				dbus_service_name = battery_service.serviceNameBuilder(
						dbus_constants.SERVICE_TYPE_BATTERY, f"neshunt_{device_instance}_sid_{self._sid}")

				self._services[name] = battery_service(
							custom_name,
							self._serial_port,
							name,
							dbus_service_name,
							device_instance,
							capacity = 0,
							onValueChangedCallback = self._dbus_battery_value_changed)

		_start_battery_service('VehicleBattery', 'Vehicle Battery')
		_start_battery_service('LeisureBattery', 'Leisure Battery')

	############################################
	# starts and stops all services
	# note: only starts the vehicle battery service
	############################################
	def _start_stop_services(self, dbusservice_name = "", newValue = None):

		if (dbusservice_name == "" or dbusservice_name.endswith('FreshWaterTank')):

			self._start_stop_tank_service('FreshWaterTank', dbus_constants.FLUID_TYPE_FRESH_WATER)

		if (dbusservice_name == "" or dbusservice_name.endswith('GreyWasteTank')):
			self._start_stop_tank_service('GreyWasteTank', dbus_constants.FLUID_TYPE_WASTE_WATER)

		if (dbusservice_name == "" or dbusservice_name.endswith('GreyWasteTank2')):
			self._start_stop_tank_service('GreyWasteTank2', dbus_constants.FLUID_TYPE_WASTE_WATER)

		if (dbusservice_name == "" or dbusservice_name.endswith("Switch")):
			self._start_stop_switch_service()

		if (dbusservice_name == ""):
			self._start_battery_services()

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
					self.update_dbus_item(key, "/Level", value)
				case 'external_lights':
					self.update_dbus_item("switches", "/SwitchableOutput/ExternalLights/State", value)
				case 'internal_lights':
					self.update_dbus_item("switches", "/SwitchableOutput/InternalLights/State", value)
				case 'water_pump':
					self.update_dbus_item("switches", "/SwitchableOutput/WaterPump/State", value)
				case 'aux':
					self.update_dbus_item("switches", "/SwitchableOutput/Aux/State", value)
				case 'vehicle_battery' | 'leisure_battery':
					self.update_dbus_item(key, "/Voltage", value)
					dbus_service = self._services.get(key, None)
					if dbus_service:
						self.update_dbus_item(key, "/Soc", dbus_service.calcBatterySoc(value))

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

		self._settings = SettingsDevice(
			bus = dbusconnection(),
			supportedSettings = {

				'/Sid': [f'{settingsPath}/Sid', self._sid, 0, 0],
				'/Sid2' : [f'{settingsPath}/Sid2', self._sid, 0, 0],
				'/ProductName' : [f'{settingsPath}/ProductName', dbus_constants.PRODUCT_NAME, "", ""],
				'/DeviceKey' : [f'{settingsPath}/DEVICE_KEY', self._sid, 0, 0],

				'/CustomName' : [f'{settingsPath}/CustomName', "", "", ""],

				'/FreshWaterTank/CustomName' : [f'{settingsPath}/FreshWaterTank/CustomName', "", "", ""],
				'/FreshWaterTank/Display': [f'{settingsPath}/FreshWaterTank/Display', 1, 0, 1],
				'/FreshWaterTank/ClassAndVrmInstance' : [f'{settingsPath}_FreshWaterTank/ClassAndVrmInstance',
										f"{dbus_constants.SERVICE_TYPE_TANK}:{dbus_constants.DEFAULT_DEVICE_INSTANCE}", 0, 0],

				'/GreyWasteTank/CustomName' : [f'{settingsPath}/GreyWasteTank/CustomName', "", "", ""],
				'/GreyWasteTank/Display': [f'{settingsPath}/FreshWaterTank/Display', 1, 0, 1],
				'/GreyWasteTank/ClassAndVrmInstance' : [f'{settingsPath}_GreyWasteTank/ClassAndVrmInstance',
										f"{dbus_constants.SERVICE_TYPE_TANK}:{dbus_constants.DEFAULT_DEVICE_INSTANCE}", 0, 0],

				'/GreyWasteTank2/CustomName' : [f'{settingsPath}/GreyWasteTank2/CustomName', "", "", ""],
				'/GreyWasteTank2/Display': [f'{settingsPath}/GreyWasteTank2/Display', 1, 0, 1],
				'/GreyWasteTank2/ClassAndVrmInstance' : [f'{settingsPath}_GreyWasteTank2/ClassAndVrmInstance',
										f"{dbus_constants.SERVICE_TYPE_TANK}:{dbus_constants.DEFAULT_DEVICE_INSTANCE}", 0, 0],

				'/VehicleBattery/CustomName' : [f'{settingsPath}/VehicleBattery/CustomName', "", "", ""],
				'/VehicleBattery/MinVoltage' : [f'{settingsPath}/VehicleBattery/MinVoltage', "", "", ""],
				'/VehicleBattery/MaxVoltage' : [f'{settingsPath}/VehicleBattery/MaxVoltage', "", "", ""],
				'/VehicleBattery/ClassAndVrmInstance' : [f'{settingsPath}_CabBattery/ClassAndVrmInstance',
										f"{dbus_constants.SERVICE_TYPE_BATTERY}:{dbus_constants.DEFAULT_DEVICE_INSTANCE}", 0, 0],

				'/LeisureBattery/CustomName' : [f'{settingsPath}/LeisureBattery/CustomName', "", "", ""],
				'/LeisureBattery/MinVoltage' : [f'{settingsPath}/LeisureBattery/MinVoltage', "", "", ""],
				'/LeisureBattery/MaxVoltage' : [f'{settingsPath}/LeisureBattery/MaxVoltage', "", "", ""],
				'/LeisureBattery/ClassAndVrmInstance' : [f'{settingsPath}_LeisureBattery/ClassAndVrmInstance',
										f"{dbus_constants.SERVICE_TYPE_BATTERY}:{dbus_constants.DEFAULT_DEVICE_INSTANCE}", 0, 0],


				'/SwitchableOutput/InternalLights/Settings/CustomName' : [f'{settingsPath}/Switches/IntenalLights/CustomName', "", "", ""],
				'/SwitchableOutput/ExternalLights/Settings/CustomName' : [f'{settingsPath}/Switches/ExternalLights/CustomName', "", "", ""],
				'/SwitchableOutput/WaterPump/Settings/CustomName' : [f'{settingsPath}/Switches/WaterPump/CustomName', "", "", ""],
				'/SwitchableOutput/Aux/Settings/CustomName' : [f'{settingsPath}/Switches/Aux/CustomName', "", "", ""],

				'/SwitchableOutput/InternalLights/Settings/Group' : [f'{settingsPath}/Switches/IntenalLights/Group', "", "", ""],
				'/SwitchableOutput/ExternalLights/Settings/Group' : [f'{settingsPath}/Switches/ExternalLights/Group', "", "", ""],
				'/SwitchableOutput/WaterPump/Settings/Group' : [f'{settingsPath}/Switches/WaterPump/Group', "", "", ""],
				'/SwitchableOutput/Aux/Settings/Group' : [f'{settingsPath}/Switches/Aux/Group', "", "", ""],

				'/SwitchableOutput/InternalLights/Settings/ShowUIControl' : [f'{settingsPath}/Switches/IntenalLights/ShowUIControl', 1, 0, 1],
				'/SwitchableOutput/ExternalLights/Settings/ShowUIControl' : [f'{settingsPath}/Switches/ExternalLights/ShowUIControl', 1, 0, 1],
				'/SwitchableOutput/WaterPump/Settings/ShowUIControl' : [f'{settingsPath}/Switches/WaterPump/ShowUIControl', 1, 0, 1],
				'/SwitchableOutput/Aux/Settings/ShowUIControl' : [f'{settingsPath}/Switches/Aux/ShowUIControl', 1, 0, 1],

				'/SwitchableOutput/InternalLights/State' : [f'{settingsPath}/Switches/IntenalLights/State', dbus_constants.TOGGLE_SWITCH_ON, 0, 1],
				'/SwitchableOutput/ExternalLights/State' : [f'{settingsPath}/Switches/ExternalLights/State', dbus_constants.TOGGLE_SWITCH_OFF, 0, 1],
				'/SwitchableOutput/WaterPump/State' : [f'{settingsPath}/Switches/WaterPump/State', dbus_constants.TOGGLE_SWITCH_ON, 0, 1],
				'/SwitchableOutput/Aux/State' : [f'{settingsPath}/Switches/Aux/State', dbus_constants.TOGGLE_SWITCH_ON, 0, 1],

				'/Switches/ClassAndVrmInstance' : [f'{settingsPath}_Switches/ClassAndVrmInstance',
										f"{dbus_constants.SERVICE_TYPE_SWITCH}:{dbus_constants.DEFAULT_DEVICE_INSTANCE}", 0, 0],

				},
			eventCallback = self._handle_changed_setting)
