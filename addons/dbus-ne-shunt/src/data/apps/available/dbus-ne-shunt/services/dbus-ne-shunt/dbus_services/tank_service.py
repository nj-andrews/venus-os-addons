from dbus_base_service import dbus_base_service
from dbus_constants import dbus_constants
import os

class tank_service(dbus_base_service):


	def __init__(self, customName:str, portName:str, name:str, serviceName:str, deviceInstance:int, fluidType:int, capacity:float, onValueChangedCallback = None):

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
				'/Capacity': {'initial': capacity,'writable': True},
				'/CustomName': {'initial': customName,'writable': True},
				'/FluidType': {'initial': fluidType, 'writable': False},
				'/Level': {'initial': 8, 'writable': True},
			},
			onValueChanged = onValueChangedCallback
		)
