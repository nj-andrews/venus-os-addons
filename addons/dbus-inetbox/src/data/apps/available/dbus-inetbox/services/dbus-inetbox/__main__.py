#!/usr/bin/env python3

from gi.repository import GLib # type: ignore
from taskmanager import TaskManager
from argparse import ArgumentParser
from contextlib import suppress

import logging
import asyncio
import sys
from inetbox_controller import InetboxController
import signal

logging.basicConfig(level=logging.INFO)
log = logging.getLogger('main')

async def dbus_loop(mainloop):

	log.info("Connected to dbus, and switching over to GLib.MainLoop() (= event based)")

	# Run mainloop in executor to avoid blocking asyncio
	loop = asyncio.get_running_loop()
	try:
		await loop.run_in_executor(None, mainloop.run)
	except asyncio.CancelledError:
		GLib.idle_add(mainloop.quit)
		raise


async def async_main(args):
	from dbus.mainloop.glib import DBusGMainLoop

	# Have a mainloop, so we can send/receive asynchronous calls to and from dbus
	DBusGMainLoop(set_as_default=True)

	tasks = TaskManager()
	mainloop = GLib.MainLoop()
	tasks.add_task("dbus_loop", lambda: dbus_loop(mainloop))

	InetboxController(
		tasks,
		args.serial,
		args.sid,
		args.debug_lin,
		args.debug_inet,
		args.record,
	)

	await asyncio.sleep(2)

	loop = asyncio.get_running_loop()
	stop_event = asyncio.Event()

	def request_shutdown():
		if not stop_event.is_set():
			log.info("Shutting down...")
			stop_event.set()

	for sig in (signal.SIGINT, signal.SIGTERM):
		try:
			loop.add_signal_handler(sig, request_shutdown)
		except NotImplementedError:
			pass

	manager_task = asyncio.create_task(tasks.main_loop())

	try:
		await stop_event.wait()
	finally:
		GLib.idle_add(mainloop.quit)
		manager_task.cancel()

		current_task = asyncio.current_task()
		pending_tasks = [
			task for task in asyncio.all_tasks()
			if task is not current_task and not task.done()
		]
		for task in pending_tasks:
			task.cancel()

		if pending_tasks:
			with suppress(asyncio.CancelledError):
				await asyncio.gather(*pending_tasks, return_exceptions=True)

		for sig in (signal.SIGINT, signal.SIGTERM):
			try:
				loop.remove_signal_handler(sig)
			except NotImplementedError:
				pass

def main():

	args = getArgs()

	# logging.basicConfig(
	# 	level=logging.INFO,
	# 	format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
	# 	#handlers=[logging.StreamHandler(sys.stdout)],
	# )

	#args.debug_lin = True
	#args.debug_inet = True

	log.info('Using serial port: ' + args.serial)
	log.info('Serial device ID: ' + args.sid)
	log.info('debug_lin: ' + str(args.debug_lin))
	log.info('debug_inet: ' + str(args.debug_inet))
	if args.record:
		log.info('Recording to: ' + args.record)

	try:
		asyncio.run(async_main(args))

	except KeyboardInterrupt:
		log.info("Shutting down...")
	finally:
		log.info("quitting...")

	log.info("Connected to dbus, and switching over to GLib.MainLoop() (= event based)")

	log.info("EXITED: dbus-inetbox")

def getArgs():
	# "--serial /dev/ttyUSB0 --debug_lin --debug_inet"
	parser = ArgumentParser(description='truma-inetbox', add_help=True)
	parser.add_argument('-s', '--serial', help='tty port (required)')
	parser.add_argument("-i", "--sid", help="serial device id (required)")
	parser.add_argument('-di', '--debug_inet', help='enable debug logging of the inetbox app',
											action='store_true')
	parser.add_argument('-dl', '--debug_lin', help='enable debug logging of the lin bus',
											action='store_true')
	parser.add_argument('-r', '--record', help='record serial traffic to file')

	args = parser.parse_args()

	if not args.serial:
		log.error('No serial port specified, see -h')
		exit(1)
	if not args.sid:
		log.error('No sid specified, see -h')
		exit(1)

	return args


if __name__ == "__main__":
	main()
