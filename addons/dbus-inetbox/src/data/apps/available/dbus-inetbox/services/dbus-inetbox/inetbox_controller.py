
# controls the interaction between the
# inetboxapp, the dbus_inetbox_service and the settings

import logging
import os
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), 'ext'))
sys.path.append(os.path.join(os.path.dirname(__file__), 'dbus_services'))

from dbus_services.dbus_constants import dbus_constants
from dbus_services.dbus_connection import dbusconnection
from ext.settingsdevice import SettingsDevice  # available in the velib_python repository
from lin import Lin
from inetboxapp import InetboxApp
from inetbox_schedules import InetboxSchedules
from taskmanager import TaskManager
from error_parser import get_error_description
from dbus_services.dbus_inetbox_service import dbusInetboxService
from datetime import datetime, timezone

class InetboxController:
	DBUS_PATH="/Values/"
	MIN_AIRCON_TARGET_TEMP = 16

	DBUS_TO_LIN_MAPPING = {
		"WaterCurrentTemp": "current_temp_water",
		"WaterTargetTemp": "target_temp_water",
		"HeatingMode": "heating_mode",
		"HeatingTargetTemp": "target_temp_room",
		"CurrentRoomTemp": "current_temp_room",
		"ElectricityPowerLevel": "el_power_level",
		"EnergyMix": "energy_mix",
		"AirconMode": "aircon_operating_mode",
		"AirconTargetTemp": "target_temp_aircon",
		"AirconFanSpeed": "aircon_vent_mode",
		"Status": "operating_status",
		"Error": "error_code",
		"Clock": "clock",
		"Alive": "alive"
	}

	LIN_TO_DBUS_MAPPING = {
		"current_temp_water": "WaterCurrentTemp",
		"target_temp_water": "WaterTargetTemp",
		"heating_mode": "HeatingMode",
		"target_temp_room": "HeatingTargetTemp",
		"current_temp_room": "CurrentRoomTemp",
		"el_power_level": "ElectricityPowerLevel",
		"energy_mix": "EnergyMix",
		"aircon_operating_mode": "AirconMode",
		"target_temp_aircon": "AirconTargetTemp",
		"aircon_vent_mode": "AirconFanSpeed",
		"operating_status": "Status",
		"error_code": "Error",
		"clock": "Clock",
		"alive": "Alive"
		}

	log = logging.getLogger(__name__)
	_serialPort : str
	_app : InetboxApp
	_lin : Lin
	_settings : SettingsDevice
	_dbusInetboxService : dbusInetboxService
	_Schedules : InetboxSchedules

	def __init__(self, tasks: TaskManager, serialPort, sid, debug_lin, debug_inet, record_file=None):

		self.log.setLevel(logging.DEBUG)
		self._serialPort = serialPort

		serviceName = dbusInetboxService.serviceNameBuilder(dbus_constants.SERVICE_CLASS_NAME, "sid_" + sid)
		self.log.debug(f'InetboxController.ctor:, serviceName={serviceName}')

		self._initializeSettings(serviceName, sid) # sets/gets class_and_vrm_instance

		self._app = InetboxApp(tasks, debug_inet)
		self._lin = Lin(self._app, serialPort, tasks, debug_lin, record_file)

		self._app.add_publish_callback(self.inetbox_value_to_dbus)

		classAndVrmInstance = self._settings['class_and_vrm_instance']
		classAndVrmInstanceParts = classAndVrmInstance.split(':')
		deviceInstance = int(classAndVrmInstanceParts[1])
		customName = self._settings['/CustomName']

		errdec = get_error_description(631)
		self.log.debug(f'AAA:ErrorDescription={errdec}')

		self._dbusInetboxService = dbusInetboxService(
				serialPort,
				serviceName,
				customName,
				deviceInstance,
				"sid_" + sid,
				self.dbus_value_to_inetbox)

		self._Schedules = InetboxSchedules(
			settings=self._settings,
			apply_callback=self.dbus_value_to_inetbox,
			logger=self.log)
		tasks.add_task("inetbox_schedules", self._Schedules.run_loop)

	# serial port -> dbus com.victronenergy.inetbox_sid_[xxxx]
	def inetbox_value_to_dbus(self, name: str, value):

		try:

			self.log.debug(f'inetbox_value_to_dbus:, {name}={value}')

			dbusName = self.map_or_debug(self.LIN_TO_DBUS_MAPPING, name)
			if dbusName == "":
				return

			if (name == "error_code"):
				error_description = get_error_description(value)
				self._dbusInetboxService.set_value(self.DBUS_PATH + "ErrorDescription", error_description)
				self._settings["/LastErrorCode"] = value
				if (int(value) > 0):
					self._settings["/LastErrorTimeStamp"] = datetime.now(timezone.utc).isoformat()
				self._dbusInetboxService.inject_notification(dbus_constants.PRODUCT_NAME, error_description)

			elif (name == "target_temp_room"): # coerse using LastHeatingTemp
				if (value == "0"):
					value = self._settings["/LastHeatingTemp"]

			elif (name == "target_temp_aircon"):
				value = self._coerce_aircon_target_temp(value)

			self._dbusInetboxService.set_value(self.DBUS_PATH + dbusName, value)

			if (name == "current_temp_room"):
				temperature_value = self._to_float(value) # MUST be a float
				if temperature_value is not None:
					self._dbusInetboxService.set_value("/Temperature", temperature_value)
			elif (name == "el_power_level" or name == "energy_mix"):
				self._toEnergyMixCombined(dbusName, value)

		except Exception as e:
			self.log.exception(
				"Exception in inetbox_value_to_dbus: name=%r, value=%r, error=%r",
				name,
				value,
				e,
			)

	# dbus service com.victronenergy.inetbox_sid_[xxxx] ->
	# serial port or
	# com.victronenergy.settings
	def dbus_value_to_inetbox(self, path : str, value ):

		try:
			if not path.startswith(self.DBUS_PATH):
				if (path == "/CustomName"):
					self._settings[path] = value
				return True

			if (path == "/Values/Error"):
				# for testing
				error_description = get_error_description(value)
				self._dbusInetboxService.set_value("/Values/ErrorDescription", error_description)
				self._dbusInetboxService.inject_notification(dbus_constants.PRODUCT_NAME, error_description)
				return True

			name = path.removeprefix(self.DBUS_PATH)
			if (name == "AirconTargetTemp"):
				value = self._coerce_aircon_target_temp(value)

			if (name == "EnergyMixCombined"):
				self.log.debug(f"dbus_value_to_inetbox: calling _fromEnergyMixCombined: {value}")
				return self._fromEnergyMixCombined(value)

			linName = self.map_or_debug(self.DBUS_TO_LIN_MAPPING, name)
			if linName == "":
				self.log.debug("dbus_value_to_inetbox: EXITING linName=\"\"")
				return False

			current_value = self._dbusInetboxService.get_value(path)
			if current_value == value:
				self.log.debug(f"dbus_value_to_inetbox: no-op for {path}={value}")
				return True

			self.log.debug(f"dbus_value_to_inetbox: calling set_status: {linName}={value}")
			self._app.set_status(linName, value)

			self._dbusInetboxService.set_value(path, value)

			if (name == "HeatingTargetTemp"):
				if (self._dbusInetboxService.get_value("/Values/HeatingMode") == "off"):
					self._settings["/LastHeatingTemp"] = value

			elif (name == "HeatingMode"):
				if (value == "off"):
					lastvalue =  self._to_float(self._dbusInetboxService.get_value("/Values/HeatingTargetTemp"))
					if (lastvalue < 4  or value > 30): value = 4
					self._settings["/LastHeatingTemp"] = lastvalue

					self.dbus_value_to_inetbox("/Values/HeatingTargetTemp", 0)
				else:
					heating_temp = self._to_float(self._dbusInetboxService.get_value("/Values/HeatingTargetTemp"))
					if (heating_temp < 5):
						heating_temp = self._settings["/LastHeatingTemp"]
						heating_temp = 5 if heating_temp < 5 else heating_temp

					self.dbus_value_to_inetbox("/Values/HeatingTargetTemp", heating_temp)

			return True
		except Exception as e:
			self.log.exception(
				"Exception in dbus_value_to_inetbox: path=%r, value=%r, error=%r",
				path,
				value,
				e,
			)
			return False

	# dbus com.victronenergy.settings changed
	def _handle_dbus_setting_changed(self, path, oldvalue, newvalue):
		try:
			self.log.info('setting changed, setting: %s, old: %s, new: %s' % (path, oldvalue, newvalue))
			if (path == "/CustomName"):
				self._dbusInetboxService.set_value(path, newvalue)
				return True

			if path.startswith("/Schedules/") and hasattr(self, "_Schedules"):
				self._Schedules.on_setting_changed(path, oldvalue, newvalue)
				return True

			return False
		except Exception as e:
			self.log.exception(
				"Exception in _handle_dbus_setting_changed: path=%r, value=%r, error=%r",
				path,
				newvalue,
				e,
			)
			return False

	def _fromEnergyMixCombined(self, value: str):
		energyMixCombined = value
		mix = ""
		elpower = ""

		if (energyMixCombined == "gas"):
			mix = "gas"
		elif (energyMixCombined == "el1"):
			elpower = "900"
			mix = "electricity"
		elif (energyMixCombined == "el2"):
			elpower = "1800"
			mix = "electricity"
		elif (energyMixCombined == "mix1"):
			elpower = "900"
			mix = "mix"
		elif (energyMixCombined == "mix2"):
			elpower = "1800"
			mix = "mix"
		else:
			return False

		self._app.set_status("energy_mix", mix)
		self._dbusInetboxService.set_value(self.DBUS_PATH + "EnergyMix", mix)

		self._app.set_status("el_power_level", elpower)
		self._dbusInetboxService.set_value(self.DBUS_PATH + "ElectricityPowerLevel", elpower)

	def _toEnergyMixCombined(self, dbusname : str, value: str):
		energyMix = ""
		elpower = ""
		energyMixCombined=""

		if (dbusname == "EnergyMix"):
			if (value != "gas"):
				elpower = self._dbusInetboxService.get_value(self.DBUS_PATH + "ElectricityPowerLevel")
			energyMix = value

		elif (dbusname == "ElectricityPowerLevel"):
			energyMix = self._dbusInetboxService.get_value(self.DBUS_PATH + "EnergyMix")
			elpower = value

		if (energyMix == "gas"):
			energyMixCombined = "gas"
		elif (energyMix == "mix"):
			if elpower == "900":
				energyMixCombined = "mix1"
			elif elpower == "1800":
				energyMixCombined = "mix2"
		elif (energyMix == "electricity"):
			if elpower == "900":
				energyMixCombined = "el1"
			elif elpower == "1800":
				energyMixCombined = "el2"

		if (energyMixCombined):
			self._dbusInetboxService.set_value(self.DBUS_PATH + "EnergyMixCombined", energyMixCombined)

	def _coerce_aircon_target_temp(self, value):
		temp = self._to_float(value)
		coerced = int(round(temp))
		if coerced < self.MIN_AIRCON_TARGET_TEMP:
			coerced = self.MIN_AIRCON_TARGET_TEMP

		if str(value) != str(coerced):
			self.log.debug(f"Coercing AirconTargetTemp from {value} to {coerced}")

		return coerced

	def _to_float(self, value):
		try:
			return float(value)
		except (TypeError, ValueError):
			self.log.warning("Skipping non-numeric temperature value: %r", value)
			return 0

	def _initializeSettings(self, service_name:str, sid:int):

		logging.debug("Initializing settings")

		# unique path used to generate unique ClassAndVrmInstance value
		# see https://github.com/victronenergy/localsettings#using-addsetting-to-allocate-a-vrm-device-instance
		self._settingsPath = f'/Settings/Devices/sid_{sid}'

		self._settings = SettingsDevice(
			bus = dbusconnection(),
			#name, path, value, min (0), max (0)
			supportedSettings = {
				'class_and_vrm_instance' : [f'{self._settingsPath}/ClassAndVrmInstance',
						f"{dbus_constants.SERVICE_CLASS_NAME}:{dbus_constants.DEFAULT_DEVICE_INSTANCE}", 0, 0],
				'/Sid' : [f'{self._settingsPath}/Sid', sid, 0, 0],
				'/Sid2' : [f'{self._settingsPath}/Sid2', sid, 0, 0],
				'/ProductName' : [f'{self._settingsPath}/ProductName', dbus_constants.PRODUCT_NAME, "", ""],
				'/ServiceName' : [f'{self._settingsPath}/ServiceName', service_name, "", ""],
				'/CustomName' : [f'{self._settingsPath}/CustomName', "", "", ""],
				'/DeviceKey' : [f'{self._settingsPath}/DeviceKey', dbus_constants.DEVICE_KEY_NAME, "", ""],
				'/LastHeatingTemp' : [f'{self._settingsPath}/LastHeatingTemp', 16, 4, 31],
				'/OverviewPage': [f'{self._settingsPath}/OverviewPage', dbus_constants.OVERVIEW_PAGE, "", ""],
				'/ShowAircon': [f'{self._settingsPath}/ShowAircon', True, 0, 1],
				'/LastErrorCode': [f'{self._settingsPath}/LastErrorCode', "", 0, 0],
				'/LastErrorTimeStamp': [f'{self._settingsPath}/LastErrorTimeStamp', "", 0, 0],

				# 1=Heating enabled;2=Water enabled|4=Aircon enabled;
				'/Schedules/State': [f'{self._settingsPath}/Schedules/State', 0, 0, 7],

				'/Schedules/Heating/Enabled': [f'{self._settingsPath}/Schedules/Heating/Enabled', 0, 0, 1],
				'/Schedules/Heating/Repeat': [f'{self._settingsPath}/Schedules/Heating/Repeat', 0, 0, 1],
				'/Schedules/Heating/Time': [f'{self._settingsPath}/Schedules/Heating/Time', "", 0, 0],
				'/Schedules/Heating/HeatingMode': [f'{self._settingsPath}/Schedules/Heating/HeatingMode', "", 0, 0],
				'/Schedules/Heating/HeatingTargetTemp': [f'{self._settingsPath}/Schedules/Heating/HeatingTargetTemp', "", 0, 0],

				'/Schedules/Water/Enabled': [f'{self._settingsPath}/Schedules/Water/Enabled', 0, 0, 1],
				'/Schedules/Water/Repeat': [f'{self._settingsPath}/Schedules/Water/Repeat', 0, 0, 1],
				'/Schedules/Water/Time': [f'{self._settingsPath}/Schedules/Water/Time', "", 0, 0],
				'/Schedules/Water/WaterTargetTemp': [f'{self._settingsPath}/Schedules/Water/WaterTargetTemp', "", 0, 0],

				'/Schedules/Aircon/Enabled': [f'{self._settingsPath}/Schedules/Aircon/Enabled', 0, 0, 1],
				'/Schedules/Aircon/Repeat': [f'{self._settingsPath}/Schedules/Aircon/Repeat', 0, 0, 1],
				'/Schedules/Aircon/Time': [f'{self._settingsPath}/Schedules/Aircon/Time', "", 0, 0],
				'/Schedules/Aircon/AirconMode': [f'{self._settingsPath}/Schedules/Aircon/AirconMode', "", 0, 0],
				'/Schedules/Aircon/AirconTargetTemp': [f'{self._settingsPath}/Schedules/Aircon/AirconTargetTemp', "", 0, 0],
				'/Schedules/Aircon/AirconFanSpeed': [f'{self._settingsPath}/Schedules/Aircon/AirconFanSpeed', "", 0, 0]
				},
			eventCallback = self._handle_dbus_setting_changed)

	def map_or_debug(self, mapping, name):
		if name in mapping:
			return mapping[name]
		else:
			#logging.debug(f"map_or_debug:unknown value {name}")
			print(f"[LIN-DEBUG] map_or_debug:unknown value {name}")
			return ""
