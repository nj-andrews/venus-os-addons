#!/usr/bin/python3 -u

import argparse
import logging
import time


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("-s", "--serial", required=True)
	parser.add_argument("-i", "--sid")
	args = parser.parse_args()

	logging.basicConfig(
		format="%(asctime)s %(levelname)-8s %(message)s",
		level=logging.INFO,
	)
	logging.info("Example 6 started for serial device %s (SID: %s)", args.serial, args.sid or "not available")

	while True:
		logging.info("Vespera Example 6 service is running")
		time.sleep(10)


if __name__ == "__main__":
	main()
