#!/usr/bin/python3 -u

import logging
import os
import sys

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

from auto_update_scheduler import AutoUpdateScheduler
from chunk_processor import ChunkProcessor
from command_processor import CommandProcessor
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
			self._settingsPath = "/Settings/Vespera"
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
			# TODO:ProductVersion
			self._dbusservice.add_path("/ProductVersion", "1.1")

			self._dbusservice.add_path("/Request/ArgsJson", "[]", writeable=True, valuetype=dbus.String)
			self._dbusservice.add_path(
					"/Request/Start",
					dbus.UInt32(0),
					writeable=True,
					valuetype=dbus.UInt32,
					onchangecallback=self._on_start_requested,
			)
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

			self._command_processor = CommandProcessor()
			self._chunk_processor = ChunkProcessor(self._dbusservice)
			self._auto_update = AutoUpdateScheduler(
					lambda: self._command_processor.start_command('["packages", "upgrade"]'))

			self._initialize_settings()
			self._dbusservice.register()

			log.info("D-Bus service registered: %s", SERVICE_NAME)
			self._loop = GLib.MainLoop()

	def run(self):
			log.info("Main loop started")
			self._loop.run()

	def _on_start_requested(self, _path, _value):
			log.info("Start requested")
			GLib.idle_add(self._command_processor.start_command, self._dbusservice["/Request/ArgsJson"])
			return True

	def _on_chunk_requested(self, _path, _value):
			return self._chunk_processor.on_chunk_requested(_path, _value)

	def _on_chunk_create_session_requested(self, _path, _value):
			return self._chunk_processor.on_create_session_requested(_path, _value)

	def _on_chunk_close_session_requested(self, _path, _value):
			return self._chunk_processor.on_close_session_requested(_path, _value)

	def _handle_dbus_setting_changed(self, setting, oldvalue, newvalue):
			try:
					log.info("setting changed, setting: %s, old: %s, new: %s", setting, oldvalue, newvalue)
					if setting == "AutoUpdate":
							self._auto_update.set_schedule(newvalue)
							return True
					return False
			except Exception:
					log.exception("Exception in _handle_dbus_setting_changed: setting=%r, value=%r", setting, newvalue)
					return False

	def _initialize_settings(self):
			log.debug("Initializing settings")

			self._settings = SettingsDevice(
					bus=self._system_bus,
					# name: [path, default, min, max]
					supportedSettings={
							'AutoUpdate': [f'{self._settingsPath}/AutoUpdate', "", 0, 0],
							# # Written by scripts/gui-executor, read by the GUI
							# not needed by vespera_service just the ui
							# 'GuiCommand': [f'{self._settingsPath}/Gui/Command', "", 0, 0],
							# 'GuiOutput': [f'{self._settingsPath}/Gui/Output', "", 0, 0],
							# 'GuiExitCode': [f'{self._settingsPath}/Gui/ExitCode', 0, 0, 0],
					},
					eventCallback=self._handle_dbus_setting_changed)

			try:
					self._auto_update.set_schedule(self._settings['AutoUpdate'])
			except Exception:
					log.exception("Failed to apply initial auto update schedule")
