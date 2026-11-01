#!/usr/bin/env python3

"""
A class to put a simple service on the dbus, according to victron standards, with constantly updating
paths. See example usage below. It is used to generate dummy data for other processes that rely on the
dbus. See files in dbus_vebus_to_pvinverter/test and dbus_vrm/test for other usage examples.

To change a value while testing, without stopping your dummy script and changing its initial value, write
to the dummy data via the dbus. See example.

https://github.com/victronenergy/dbus_vebus_to_pvinverter/tree/master/test
"""

from gi.repository import GLib
import platform
import logging
import os
import dbus

from dbus_connection import dbusconnection
from ext.vedbus import VeDbusService
from ext.vedbus import VeDbusItemImport

class dbus_base_service(object):

	_dbusservice = None
	_bus = None
	_sid:int = 0
	_name:str = ""

	# Create the mandatory objects
	def unregister(self):
		"""
		Unregister the dbus service.
		"""
		if self._dbusservice:
			self._dbusservice.__del__()
			self._dbusservice = None
			self._bus = None
			logging.debug("Unregistered %s" % (self._dbusservice))
		else:
			logging.debug("No dbus service to unregister")


	def _registerCore(self, connection:str,
                   deviceInstance: int,
									 name: str,
                   serviceName:str,
                   productId:int,
                   productName:str,
                   firmwareVersion:str,
                   hardwareVersion:str,
                   paths, onValueChanged = None):

		logging.debug("_registerCore in")

		self._bus = dbusconnection()
		self._name = name
		self._valueChangedCallback = onValueChanged
		self._dbusservice = VeDbusService(serviceName, bus=self._bus, register=False)

		self._paths = paths
		callback = None
		if self._valueChangedCallback != None:
			callback = self._on_valueChanged

		# Create the management objects, as specified in the ccgx dbus-api document
		self._dbusservice.add_mandatory_paths(__file__,
			'Unknown version, and running on Python ' + platform.python_version(),
			connection,
			deviceInstance,
			productId,
			productName,
			firmwareVersion,
			hardwareVersion,
			1)

		for path, settings in self._paths.items():
			self._dbusservice.add_path(
				path,
				value = settings["initial"],
				writeable = settings["writable"],
				onchangecallback = callback)

		self._dbusservice.register()


	def _on_valueChanged(self, path, value):
		if self._valueChangedCallback:
			try:
				return self._valueChangedCallback(self._name, path, value)
			except Exception as ex:
				logging.error("Error in _on_valueChanged %s" % (ex))



	def get_value(self, path):
		"""
		Get the value of a path.
		"""
		if (self._dbusservice == None):
			return None

		return self._dbusservice[path]

	def set_value(self, path, value):
		"""
		Set the value of a path.
		"""
		if (self._dbusservice == None):
			return False

		with self._dbusservice as s:
			s[path] = value
			logging.debug("Set %s to %s" % (path, value))
		return True

	def set_dbus_value(self, service,path,value):
		bus = self._bus
		if bus is None:
			logging.error("Cannot inject notification: no dbus connection found")
			return False

		obj = bus.get_object(service, path)
		iface = dbus.Interface(obj, "com.victronenergy.BusItem")
		iface.SetValue(value, timeout=2)

	def inject_notification(self, title: str, message: str, level: str = "alarm"):

		title = (title or "")[:100]
		message = (message or "")[:500]
		payload = f"{level}\t{title}\t{message}"

		try:
			if not (self.set_dbus_value("com.victronenergy.platform","/Notifications/Inject",dbus.String(payload))):
				return False
			if not (self.set_dbus_value("com.victronenergy.platform","/Notifications/Alarm",dbus.Boolean(True))):
				return False

			logging.debug("Injected notification level=%s title=%s", level, title)
			return True
		except Exception:
			logging.exception("Failed to inject notification")
			return False

	@property
	def serviceName(self):
		if (self._dbusservice == None):
			return None
		return self._dbusservice.name

	@property
	def name(self):
		return self._name

	@staticmethod
	def serviceNameBuilder(className:str, serviceIdentifier:str) -> str:
		return "com.victronenergy.{}.{}".format(
			className, serviceIdentifier)
