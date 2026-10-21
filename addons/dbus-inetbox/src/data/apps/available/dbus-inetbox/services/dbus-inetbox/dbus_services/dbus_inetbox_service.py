#!/usr/bin/env python3

from dbus_base_service import dbus_base_service
import os
from dbus_constants import dbus_constants

class dbusInetboxService(dbus_base_service):

	def __init__(self, portName:str, serviceName:str,customName:str, deviceInstance:int, sid:str, onValueChangedCallback = None):

		connection = os.path.basename(portName) # convert from /dev/ttyxxx to ttyxxx

		self._registerCore(
			connection,
			deviceInstance,
			serviceName,
			dbus_constants.PRODUCT_ID,
			dbus_constants.PRODUCT_NAME,
			dbus_constants.PRODUCT_VERSION,
			'',
			'',
			paths =  {
				'/Sid': {'initial': sid,'writable': False},
				'/CustomName': {'initial': customName,'writable': True },
				'/State': {'initial': 0x100, 'writable': False},
				'/CustomAlarm': {'initial': 0,'writable': True},
				'/CustomAlarmText': {'initial': "",'writable': True},
				'/Temperature': {'initial': "",'writable': False},
				'/Values/WaterCurrentTemp': {'initial': None,'writable': False},
				'/Values/WaterTargetTemp': {'initial': None,'writable': True},
				'/Values/HeatingMode': {'initial': None,'writable': True},
				'/Values/HeatingTargetTemp': {'initial': None,'writable': True},
				'/Values/CurrentRoomTemp': {'initial': None,'writable': False},
				'/Values/ElectricityPowerLevel': {'initial': None,'writable': True},
				'/Values/EnergyMix': {'initial': None,'writable': True},
				'/Values/EnergyMixCombined': {'initial': None,'writable': True},
				'/Values/AirconMode': {'initial': None,'writable': True},
				'/Values/AirconTargetTemp': {'initial': None,'writable': True},
				'/Values/AirconFanSpeed': {'initial': None,'writable': True},
				'/Values/Status': {'initial': None,'writable': False},
				'/Values/Error': {'initial': None,'writable': True},
				'/Values/ErrorDescription': {'initial': None,'writable': True},
				'/Values/Clock': {'initial': None,'writable': False},
				'/Values/Alive': {'initial': None,'writable': False},
				'/ScheduleState': {'initial': 0,'writable': False},
				# '/SwitchableOutput/heating/Settings/ShowUIControl': {'initial': 0,'writable': False},
				# '/SwitchableOutput/heating/Settings/Type': {'initial': 3,'writable': False},
				# '/SwitchableOutput/heating/Settings/Unit': {'initial': '/Temperature','writable': False},
				# '/SwitchableOutput/heating/Settings/DimmingMin': {'initial': 5,'writable': False},
				# '/SwitchableOutput/heating/Settings/DimmingMax': {'initial': 30,'writable': False},
				# '/SwitchableOutput/heating/Settings/StepSize': {'initial': 1,'writable': False},
				# '/SwitchableOutput/heating/Settings/Decimals': {'initial': 1,'writable': False},
				# '/SwitchableOutput/heating/Dimming': {'initial': None,'writable': True},
				# '/SwitchableOutput/heating/Measurement': {'initial': None,'writable': False},

				# '/SwitchableOutput/aircon/Dimming': {'initial': None,'writable': True},
				# '/SwitchableOutput/aircon/Settings/ShowUIControl': {'initial': 0,'writable': False},
				# '/SwitchableOutput/aircon/Settings/Type': {'initial': 3,'writable': False},
				# '/SwitchableOutput/aircon/Settings/Unit': {'initial': '/Temperature','writable': False},
				# '/SwitchableOutput/aircon/Settings/DimmingMin': {'initial': 16,'writable': False},
				# '/SwitchableOutput/aircon/Settings/DimmingMax': {'initial': 31,'writable': False},
				# '/SwitchableOutput/aircon/Settings/StepSize': {'initial': 1,'writable': False},
				# '/SwitchableOutput/aircon/Settings/Decimals': {'initial': 1,'writable': False},
				# '/SwitchableOutput/aircon/Measurement': {'initial': None,'writable': False},


				# '/SwitchableOutput/output_1/Settings/ShowUIControl': {'initial': 1,'writable': False},
				# '/SwitchableOutput/output_1/Name': {'initial': "Test",'writable': True},
				# '/SwitchableOutput/output_1/Settings/Adjustable': {'initial': 0,'writable': True},
				# '/SwitchableOutput/output_1/Settings/CustomName': {'initial': "Water",'writable': True},
				# '/SwitchableOutput/output_1/Settings/Group': {'initial': "Inetbox",'writable': True},
				# '/SwitchableOutput/output_1/Settings/Type': {'initial': 1,'writable': True},
				# '/SwitchableOutput/output_1/Settings/ValidTypes': {'initial': 2,'writable': True},
				# '/SwitchableOutput/output_1/State': {'initial': 0,'writable': True},
				# '/SwitchableOutput/output_1/Status': {'initial': 0,'writable': True}
			},
			onValueChanged = onValueChangedCallback

			)
