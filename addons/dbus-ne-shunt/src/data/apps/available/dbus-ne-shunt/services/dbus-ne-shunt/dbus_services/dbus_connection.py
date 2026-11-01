
import os
from dbus import bus

# our own packages
#sys.path.insert(1, os.path.join(os.path.dirname(__file__), '../../ext/velib_python'))

class SystemBus(bus.BusConnection):
	def __new__(cls):
		return bus.BusConnection.__new__(cls, bus.BusConnection.TYPE_SYSTEM)
 
class SessionBus(bus.BusConnection):
	def __new__(cls):
		return bus.BusConnection.__new__(cls, bus.BusConnection.TYPE_SESSION)
 
def dbusconnection():
	return SessionBus() if 'DBUS_SESSION_BUS_ADDRESS' in os.environ else SystemBus()
