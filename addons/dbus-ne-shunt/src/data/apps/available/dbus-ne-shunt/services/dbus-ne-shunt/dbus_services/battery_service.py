#!/usr/bin/env python3

from dbus_base_service import dbus_base_service
from dbus_constants import dbus_constants
import os

class battery_service(dbus_base_service):

	MinVoltage = 11.63
	MaxVoltage = 12.89

	def __init__(self, customName:str, portName:str, name:str, serviceName:str, deviceInstance:int, capacity:float, onValueChangedCallback = None):

		connection = os.path.basename(portName) # convert from /dev/ttyxxx to ttyxxx

		self._registerCore(
			connection,
			deviceInstance,
			name,
			serviceName,
			dbus_constants.PRODUCT_ID,
			dbus_constants.PRODUCT_NAME,
			dbus_constants.FIRMWARE_VERSION,
			dbus_constants.HARDWARE_VERSION,
			paths =  {
				'/Voltage': {'initial': None,'writable': False},
				'/CustomName': {'initial': customName,'writable': True},
				'/Soc': {'initial': None,'writable': True},
				'/Capacity': {'initial': capacity,'writable': True},
				'/MinVoltage': {'initial': self.MinVoltage,'writable': True},
				'/MaxVoltage': {'initial': self.MaxVoltage,'writable': True}
				},
			onValueChanged = onValueChangedCallback
			)


	def calcBatterySoc(self, value):
		if (value == None):
			return 0
		#V_MAX = 12.89 # 100% charged
		V_MIN = 11.63 # 0% dead
		V_RANGE = 1.26 # (V_MAX - V_MIN)
		#soc = (float(value) - V_MIN) / (V_MAX - V_MIN)

		soc = ((float(value) - V_MIN) / (self.MaxVoltage - self.MinVoltage)) * 100

		return soc
