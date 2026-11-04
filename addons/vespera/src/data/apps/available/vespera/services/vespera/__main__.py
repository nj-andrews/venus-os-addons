#!/usr/bin/env python3

import importlib.util
import logging
import os
import signal
import sys
import threading

THIS_DIR = os.path.dirname(os.path.abspath(__file__))
EXT_DIR = os.path.join(THIS_DIR, "ext")

if THIS_DIR not in sys.path:
		sys.path.insert(0, THIS_DIR)

if EXT_DIR not in sys.path:
		sys.path.insert(0, EXT_DIR)

from vespera_service import VesperaService

class LevelFilter(logging.Filter):
		def __init__(self, passlevels, reject):
				self.passlevels = passlevels
				self.reject = reject

		def filter(self, record):
				if self.reject:
						return (record.levelno not in self.passlevels)
				else:
						return (record.levelno in self.passlevels)


# Leave the name set to None to get the root logger. For some reason specifying 'root' has a
# different effect: there will be two root loggers, both with their own handlers...
def setup_logging(debug=False, name=None):
		formatter = logging.Formatter(fmt='%(levelname)s:%(module)s:%(message)s')

		# Make info and debug stream to stdout and the rest to stderr
		h1 = logging.StreamHandler(sys.stdout)
		h1.addFilter(LevelFilter([logging.INFO, logging.DEBUG], False))
		h1.setFormatter(formatter)

		h2 = logging.StreamHandler(sys.stderr)
		h2.addFilter(LevelFilter([logging.INFO, logging.DEBUG], True))
		h2.setFormatter(formatter)

		logger = logging.getLogger(name)
		for handler in list(logger.handlers):
				logger.removeHandler(handler)
		logger.addHandler(h1)
		logger.addHandler(h2)
		logger.propagate = False

		# Set the loglevel and show it
		logger.setLevel(level=(logging.DEBUG if debug else logging.INFO))
		log_level = {0: 'NOTSET', 10: 'DEBUG', 20: 'INFO', 30: 'WARNING', 40: 'ERROR'}
		logger.info('Loglevel set to ' + log_level[logger.getEffectiveLevel()])

		return logger


log = setup_logging(debug=(os.getenv("VESPERA_LOG_LEVEL", "INFO").upper() == "DEBUG"), name=None)


def _log_unhandled_exception(exc_type, exc_value, exc_traceback):
		if issubclass(exc_type, KeyboardInterrupt):
				sys.__excepthook__(exc_type, exc_value, exc_traceback)
				return
		log.critical("Unhandled exception", exc_info=(exc_type, exc_value, exc_traceback))


def _log_thread_exception(args):
		_log_unhandled_exception(args.exc_type, args.exc_value, args.exc_traceback)


sys.excepthook = _log_unhandled_exception
threading.excepthook = _log_thread_exception


def main():
		log.info("Starting vespera service process")
		pid = os.getpid()
		log.info("Process PID: %s", pid)
		service = VesperaService()

		service.run()


if __name__ == "__main__":
		main()
