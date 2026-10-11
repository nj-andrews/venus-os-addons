#!/usr/bin/python3 -u

import logging
import os
import sys
import threading

import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib  # type: ignore

THIS_DIR = os.path.dirname(os.path.abspath(__file__))
EXT_DIR = os.path.join(THIS_DIR, "ext")

if THIS_DIR not in sys.path:
		sys.path.insert(0, THIS_DIR)

if EXT_DIR not in sys.path:
		sys.path.insert(0, EXT_DIR)

from vedbus import VeDbusService  # type: ignore
from settingsdevice import SettingsDevice  # type: ignore

from chunk_processor import ChunkProcessor
from command_processor import CommandProcessor
from usb_scanner import UsbScanner
from vespera_config import VesperaConfig

SERVICE_NAME = "com.victronenergy.vespera"
#DUMMY_SERVICE_NAME = "com.victronenergy._vespera"
VERSION = "2.1.2"

log = logging.getLogger(__name__)

class VesperaService:

		def __init__(self):
				DBusGMainLoop(set_as_default=True)
				log.info("Initializing service %s version=%s", SERVICE_NAME, VERSION)

				self._settings = None
				self._system_bus = dbus.SystemBus()
				self._config = VesperaConfig()
				log.info("Loaded Vespera config from %s", self._config.config_path)

				self._dbusservice = VeDbusService(SERVICE_NAME, bus=self._system_bus, register=False)
				self._dbusservice.add_mandatory_paths(
						processname=__file__,
						processversion=VERSION,
						connection="vespera",
						deviceinstance=0,
						productid=0,
						productname=".vespera.", # makes sure we are top of the device list
						firmwareversion=1,
						hardwareversion=1,
						connected=1,
				)

				self._dbusservice.add_path("/ServiceName", "vespera")

				self._dbusservice.add_path("/Request/ArgsJson", "[]", writeable=True, valuetype=dbus.String)
				self._dbusservice.add_path(
						"/Request/Start",
						dbus.UInt32(0),
						writeable=True,
						valuetype=dbus.UInt32,
						onchangecallback=self._on_start_requested,
				)
				self._dbusservice.add_path(
						"/Request/Cancel",
						dbus.UInt32(0),
						writeable=True,
						valuetype=dbus.UInt32,
						onchangecallback=self._on_cancel_requested,
				)

				self._dbusservice.add_path("/State/RequestId", "", valuetype=dbus.String)
				self._dbusservice.add_path("/State/Status", dbus.UInt16(0), valuetype=dbus.UInt16)

				self._dbusservice.add_path("/Event/StdoutLine", "", valuetype=dbus.String)
				self._dbusservice.add_path("/Event/StdoutSeq", dbus.UInt32(0), valuetype=dbus.UInt32)
				self._dbusservice.add_path("/Event/StderrLine", "", valuetype=dbus.String)
				self._dbusservice.add_path("/Event/StderrSeq", dbus.UInt32(0), valuetype=dbus.UInt32)
				self._dbusservice.add_path("/Event/FinishedSeq", dbus.UInt32(0), valuetype=dbus.UInt32)

				self._dbusservice.add_path("/Result/ExitCode", 0, valuetype=dbus.Int32)
				self._dbusservice.add_path("/Result/ExitStatus", dbus.UInt16(0), valuetype=dbus.UInt16)
				self._dbusservice.add_path("/Result/Error", "", valuetype=dbus.String)
				self._dbusservice.add_path("/Result/Json", "", valuetype=dbus.String, writeable=True)

				self._dbusservice.add_path(
						"/Chunk/Control/CreateSessionId",
						"",
						writeable=True,
						valuetype=dbus.String,
						onchangecallback=self._on_chunk_create_session_requested,
				)
				self._dbusservice.add_path(
						"/Chunk/Control/CloseSessionId",
						"",
						writeable=True,
						valuetype=dbus.String,
						onchangecallback=self._on_chunk_close_session_requested,
				)
				self._dbusservice.add_path(
						"/Chunk/RequestJson",
						"",
						writeable=True,
						valuetype=dbus.String,
						onchangecallback=self._on_chunk_requested,
				)

				lock = threading.RLock()
				self._usb_scanner = UsbScanner(self._dbusservice)
				self._command_processor = CommandProcessor(self._dbusservice, lock, self._usb_scanner)
				self._chunk_processor = ChunkProcessor(self._dbusservice)

				# self._initialize_settings()
				self._dbusservice.register()

				log.info("D-Bus service registered: %s", SERVICE_NAME)
				self._loop = GLib.MainLoop()

		# def _initialize_settings(self):
		# 		try:
		# 				self._settings = SettingsDevice(
		# 						bus=self._system_bus,
		# 						supportedSettings={
		# 								"auto_scan": ["/Settings/Vespera/AutoScan", 0, 0, 1],
		# 						},
		# 						eventCallback=self._on_setting_changed,
		# 						timeout=30,
		# 				)
		# 		except Exception:
		# 				log.exception("Failed to initialize settings device")
		#  				self._settings = None

		# def _on_setting_changed(self, setting, oldvalue, newvalue):
		# 		log.info("Setting changed: %s %s -> %s", setting, oldvalue, newvalue)
		# 		return True

		def run(self):
				log.info("Main loop started")
				self._loop.run()

		def _on_start_requested(self, _path, _value):
				log.info("Start requested")
				GLib.idle_add(self._command_processor.start_command)
				return True

		def _on_cancel_requested(self, _path, _value):
				log.info("Cancel requested")
				# Set cancelled synchronously here (on the main thread) so that any
				# drain idle callbacks already in the GLib queue will see the flag.
				self._command_processor.mark_cancelled_sync()
				GLib.idle_add(self._command_processor.cancel_command)
				return True

		def _on_chunk_requested(self, _path, _value):
				return self._chunk_processor.on_chunk_requested(_path, _value)

		def _on_chunk_create_session_requested(self, _path, _value):
				return self._chunk_processor.on_create_session_requested(_path, _value)

		def _on_chunk_close_session_requested(self, _path, _value):
				return self._chunk_processor.on_close_session_requested(_path, _value)
