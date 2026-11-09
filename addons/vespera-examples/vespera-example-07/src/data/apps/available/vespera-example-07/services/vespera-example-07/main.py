#!/usr/bin/python3 -u

import logging

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

SERVICE_NAME = "com.victronenergy.ve_example_07"

class BusValue(dbus.service.Object):
	def __init__(self, bus_name, path):
		self._value = dbus.Int32(0)
		super().__init__(bus_name, path)

	@dbus.service.method("com.victronenergy.BusItem", in_signature="", out_signature="v")
	def GetValue(self):
		return self._value

	@dbus.service.method("com.victronenergy.BusItem", in_signature="v", out_signature="i")
	def SetValue(self, value):
		try:
			self._value = dbus.Int32(value)
		except (TypeError, ValueError):
			return 1
		return 0

	@dbus.service.method("com.victronenergy.BusItem", in_signature="", out_signature="s")
	def GetText(self):
		return str(self._value)


def main():
	logging.basicConfig(
		format="%(levelname)-8s %(message)s",
		level=logging.INFO,
	)
	DBusGMainLoop(set_as_default=True)
	bus = dbus.SystemBus()
	bus_name = dbus.service.BusName(SERVICE_NAME, bus=bus, do_not_queue=True)
	value = BusValue(bus_name, "/Value")
	main_loop = GLib.MainLoop()

	def report_value():
		logging.info("%s /Value = %s", SERVICE_NAME, value._value)
		return GLib.SOURCE_CONTINUE

	GLib.timeout_add_seconds(10, report_value)
	logging.info("D-Bus service %s is ready", SERVICE_NAME)
	main_loop.run()


if __name__ == "__main__":
	main()
