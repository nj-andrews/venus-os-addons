from dbus_base_service import dbus_base_service
from dbus_constants import dbus_constants
import os
from ext.settingsdevice import SettingsDevice  # available in the velib_python repository

class switch_service(dbus_base_service):

	OUTPUT_TYPE_LATCHING = 1
	MODULE_STATE_CONNECTED = 0x100

	STATUS_OFF = 0x00
	STATUS_ON = 0x09
	STATUS_OUTPUT_FAULT = 0x08
	STATUS_DISABLED = 0x20

	OUTPUT_FUNCTION_MANUAL = 2


	def __init__(self, settings:SettingsDevice, sid:str, customName:str, portName:str, name:str, serviceName:str, deviceInstance:int, switches:list[str], onValueChangedCallback):

		connection = os.path.basename(portName) # convert from /dev/ttyxxx to ttyxxx

		validTypesLatching = 1 << self.OUTPUT_TYPE_LATCHING

		paths = {f'/State': {'initial': self.MODULE_STATE_CONNECTED, 'writable': True},
						f'/CustomName': {'initial': customName, 'writable': True}
		}

		for switchName in switches:

			# /SwitchableOutput/InternalLights/Settings/CustomName
			switchName =  switchName.replace(" ", "")
			key = '/SwitchableOutput/' + switchName

			paths[key + '/Name'] = {'initial': switchName, 'writable': False}
			paths[key + '/Settings/Type'] = {'initial': self.OUTPUT_TYPE_LATCHING, 'writable': False}
			paths[key + '/Settings/ValidTypes'] = {'initial': validTypesLatching, 'writable': False}

			switch_state = settings[key + '/State']
			paths[key + '/State'] = {'initial': switch_state, 'writable': True}
			switch_states = 0x9 if switch_state == 1 else 0x0

			paths[key + '/Status'] = {'initial': switch_states, 'writable': True}
			paths[key + '/Settings/Group'] = {'initial': settings[key + '/Settings/Group'], 'writable': True}
			paths[key + '/Settings/CustomName'] = {'initial': settings[key + '/Settings/CustomName'], 'writable': True}
			paths[key + '/Settings/ShowUIControl'] = {'initial': settings[key + '/Settings/ShowUIControl'], 'writable': True}

		self._registerCore(
			connection,
			deviceInstance,
			name,
			serviceName,
			dbus_constants.PRODUCT_ID,
			dbus_constants.PRODUCT_NAME,
			dbus_constants.FIRMWARE_VERSION,
			dbus_constants.HARDWARE_VERSION,
			paths = paths,
			onValueChanged = onValueChangedCallback
		)

	def set_switch_status(self, path, checked):
		states_flags = self.STATUS_ON if checked == 1 else self.STATUS_OFF
		return self.set_value(path, states_flags)

	def ShowUIControl(self, name):
		return self.get_value(f"/SwitchableOutput/{name}/Settings/ShowUIControl")