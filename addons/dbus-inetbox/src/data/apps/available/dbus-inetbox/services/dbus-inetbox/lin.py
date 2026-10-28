# MIT License
#
# Copyright (c) 2022  Dr. Magnus Christ (mc0110)
#
#
# version 0.8.2
#
# this project is based on the LIN Specification Package Revision 2.2A
#
# The essential basis is to incorporate the results of the specification in such a way that
# there are no performance problems. Therefore, for example, RAW PIDs are processed in which
# the parity bits have not been separated. These are shown on pages 53ff of the specification.
# Thus 3C/3D with parity becomes 3C/7D. If this leads to confusion, I apologise.
# Same approach for the raw PID 0xD8. This corresponds to a PID 0x18
# This module has been optimised for high performance.

import inetboxapp
import serial
from taskmanager import TaskManager
from calculate_checksum import calculate_checksum
from lin_recorder import LinRecorder
import logging
import asyncio
import logging
import sys
import time
import os
import json

class Lin:

		ts_response_buffer = []
		cpp_in_buffer = [bytes([]),bytes([]),bytes([]),bytes([]),bytes([]),bytes([])]
		updates_to_send = False
		update_request = False
		cpp_buffer = {}
		cmd_buf = {}
		cnt_rows = 1
		stop_async = False
		log = logging.getLogger(__name__)

		app : inetboxapp.InetboxApp
		# Same approach for the raw PID 0xD8. This corresponds to a PID 0x18
		d8_alive = False

		# Only for display control / slow event timing
		CNT_ROWS_MAX = 200

		# /data persists on Venus OS (logs are rotated); override with INETBOX_DUMP_DIR
		DUMP_DIR = os.environ.get("INETBOX_DUMP_DIR", "/data/log/dbus-inetbox/lin-dumps")
		DUMP_KEEP = 20

		# Check Alive-status periodically - with 1ms delay it is appx. 9s
		# there must be more than 1 D8-requests in this periode, than is alive status "ON"
		# otherwise it would set "OFF"

		STATUS_INTERVAL = 9.0  # Run status logic every 9 seconds

		DISPLAY_STATUS_PIDS = [bytes([0x20]), bytes([0x61]), bytes([0xE2])]


		# the correct (full) preamble starts in the first frame, but we see only one type of
		# frames, all with the same length - so we can use a frame-preamble with a shorter length,
		# starting in the 2. frame
		BUFFER_PREAMBLE = bytes([0x00, 0x00, 0x22, 0xFF, 0xFF, 0xFF, 0x54, 0x01])


		BUFFER_HEADER_RECV  = bytes([0x14, 0x33])
		BUFFER_HEADER_TIMER = bytes([0x18, 0x3D])
		BUFFER_HEADER_02    = bytes([0x02, 0x0D])
		BUFFER_HEADER_03    = bytes([0x0A, 0x15])
		BUFFER_HEADER_WRITE = bytes([0x0C, 0x32])


		def __init__(self, app : inetboxapp.InetboxApp, port : str, tasks : TaskManager, lin_debug, record_file=None):
			self.loop_state = False
			self.serial = serial.Serial(
				port,
				baudrate=9600,
				bytesize=serial.EIGHTBITS,
				parity=serial.PARITY_NONE,
				stopbits=serial.STOPBITS_ONE,
				xonxoff=False,
				rtscts=False,
				dsrdtr=False,
				#timeout=0.003,
				timeout=1.0,
			)

			# Initialize recorder if file specified
			self.recorder = LinRecorder(record_file) if record_file else None

			self._rx_buf = bytearray()
			self.cnt_rows = 1
			if lin_debug:
					self.log.setLevel(logging.DEBUG)
			else:
					self.log.setLevel(logging.INFO)

			self.lin_debug = lin_debug

			self.app = app
			if not(tasks==None):
				tasks.add_task("lin_loop", self._lin_loop)

			print("Lin initialized")
			if self.recorder:
				print(f"Recording enabled: {record_file}")

		def response_waiting(self):
			return len(self.ts_response_buffer)


		def _send_answer_str(self, data_str):
			self._send_answer(bytes.fromhex(data_str.replace(" ","")))


		def _send_answer_w_cs_calc(self, databytes, pid_for_checksum=None):
				if not pid_for_checksum:
						cs = calculate_checksum(databytes)
				else:
						cs = calculate_checksum(bytes([pid_for_checksum]) + databytes)
				self._send_answer(databytes.extend([cs]))


		def _send_answer(self, databytes):
			if self.recorder:
				self.recorder.record_write(databytes)
			self.serial.write(databytes)
			#self.serial.flush()
			time.sleep(0.002)
			self.log.debug(f"[LIN-DEBUG] out > {databytes.hex(' ')}")


		def prepare_tl_str_response(self, message_str, info_str):
				self.prepare_tl_response(bytes.fromhex(message_str.replace(" ","")))
				#if info_str.startswith("_"):
				#		self.log.debug(info_str)
				#else:
				#		self.log.info(info_str)

		def prepare_tl_response(self, messages):
				self.ts_response_buffer.extend([messages])

		def _answer_tl_request(self):
				if len(self.ts_response_buffer):
						databytes = bytes(self.ts_response_buffer[0])
						self.ts_response_buffer.pop(0)
						self._send_answer(databytes)
				else:
						self.log.debug("unexpacted behavior - nothing to send")


		def no_answer(self, s, p):
				if self.stop_async:
						self.stop_async = self.response_waiting()
				self.updates_to_send = (self.app.upload_buffer or self.app.upload02_buffer)
				if p.startswith("_"): return
				self.log.debug(p)


		def display_status(self):
				pass
#        if self.info:
#            print()
#            print("Overview received buffers")
#            for key in self.cpp_buffer.keys():
#                 print(f"Buf[{key}]={self.cpp_buffer[key]}")
#            print("-----------------------------")
#            print()


		def assemble_cpp_buffer(self):
				# gather the transfered frames
				# preamble "00 1E 00 00 0x22 0xFF 0xFF 0x54 0x01"
				# buffer id (2 bytes)
				buf = bytes([])
				for i in range(5):
						buf += self.cpp_in_buffer[i]
				#print(buf.hex("+"))
				if buf[:8] != self.BUFFER_PREAMBLE:
						#self.log.debug("buffer preamble doesn't match")
						return False
				buf_id = buf[8:10]
				self.d8_alive = True
				self.cpp_buffer[buf_id] = buf[10:]
				self.log.debug(f"Buf[{buf_id}]={self.cpp_buffer[buf_id]}")
				self.app.process_status_buffer_update(buf_id, self.cpp_buffer[buf_id])
				return True


		# send out - warm water
		def generate_inet_upload(self, s, p):

				# Message warm water / counter = 1
#         self.prepare_tl_response(bytes.fromhex("03 10 29 fa 00 1f 00 1e 8b".replace(" ","")))
#         self.prepare_tl_response(bytes.fromhex("03 21 00 00 22 ff ff ff b9".replace(" ","")))
#         self.prepare_tl_response(bytes.fromhex("03 22 54 01 0c 32 02 22 23".replace(" ","")))
#         self.prepare_tl_response(bytes.fromhex("03 23 00 00 00 00 00 00 d9".replace(" ","")))
#         self.prepare_tl_response(bytes.fromhex("03 24 3a 0c 00 00 01 01 90".replace(" ","")))
#         self.prepare_tl_response(bytes.fromhex("03 25 00 00 00 00 00 00 d7".replace(" ","")))
#         self.prepare_tl_response(bytes.fromhex("03 26 00 00 00 00 00 00 d6".replace(" ","")))

				if self.app.upload_buffer:
						self.log.debug("heater_status to be generated")
						self.cmd_buf = self.app._get_status_buffer_for_writing()
						self.stop_async = True
						if self.app.upload_buffer > 0: self.app.upload_buffer -= 1

				if self.app.upload02_buffer:
						self.log.debug("aircon_status to be generated")
						self.cmd_buf = self.app._get_status_buffer1_for_writing()
						self.stop_async = True
						if self.app.upload02_buffer > 0: self.app.upload02_buffer -= 1

				if (self.cmd_buf == None) or (self.cmd_buf == {}):
						self.log.debug("cmd_buffer is empty")
						return
				self.d8_alive = True
				self.stop_async = True
				for i in self.cmd_buf:
						self.prepare_tl_response(i)
				self.updates_to_send = False
				if p.startswith("_"): return
				self.log.debug(p)

		async def watchdog(self):
				self.log.info("watchdog activated")
				# allow time for the device itself to reboot before resetting
				for stage in (1, 2, 3):
						await asyncio.sleep(60)
						if (self.app.status["alive"][0] == "ON"):
								self.log.info(f"watchdog deactivated_s{stage}")
								return
				self.log.warning("watchdog: alive still OFF - dumping state and resetting")
				self.dump_state()
				self.reset()


		def dump_state(self):
				try:
						state = {
								"serial_open": self.serial.is_open,
								"serial_in_waiting": self.serial.in_waiting if self.serial.is_open else None,
								"rx_buf": bytes(self._rx_buf).hex(" "),
								"ts_response_buffer": [bytes(b).hex(" ") for b in self.ts_response_buffer],
								"cpp_in_buffer": [bytes(b).hex(" ") for b in self.cpp_in_buffer],
								"cpp_buffer": {k.hex(): bytes(v).hex(" ") for k, v in self.cpp_buffer.items()},
								"cmd_buf": repr(self.cmd_buf),
								"d8_alive": self.d8_alive,
								"stop_async": self.stop_async,
								"updates_to_send": self.updates_to_send,
								"update_request": self.update_request,
								"cnt_rows": self.cnt_rows,
								"upload_buffer": self.app.upload_buffer,
								"upload02_buffer": self.app.upload02_buffer,
								"upload_wait": self.app.upload_wait,
								"app_status": repr(self.app.status),
						}
						os.makedirs(self.DUMP_DIR, exist_ok=True)
						path = os.path.join(self.DUMP_DIR, time.strftime("lin-dump-%Y%m%d-%H%M%S.json"))
						with open(path, "w") as f:
								json.dump(state, f, indent=2, default=repr)
						self.log.warning(f"[LIN-DUMP] state written to {path}")
						# keep only the newest dumps
						dumps = sorted(n for n in os.listdir(self.DUMP_DIR) if n.startswith("lin-dump-"))
						for old in dumps[:-self.DUMP_KEEP]:
								os.remove(os.path.join(self.DUMP_DIR, old))
				except Exception:
						self.log.exception("dump_state failed")


		# Equivalent to a service restart for the LIN layer. Runs synchronously on the
		# event loop, so it cannot interleave with _lin_loop.
		def reset(self):
				self.log.warning("resetting lin state")
				self.ts_response_buffer = []
				self.cpp_in_buffer = [bytes([]) for _ in range(6)]
				self.cpp_buffer = {}
				self.cmd_buf = {}
				self._rx_buf = bytearray()
				self.updates_to_send = False
				self.update_request = False
				self.stop_async = False
				self.d8_alive = False
				self.cnt_rows = 1
				self.app.upload_buffer = 0
				self.app.upload02_buffer = 0
				self.app.upload_wait = 1
				try:
						self.serial.close()
						self.serial.open()
						self.serial.reset_input_buffer()
						self.serial.reset_output_buffer()
				except Exception:
						self.log.exception("serial reopen failed")


		# check alive status
		def status_monitor_timed(self):

			self.app.status["alive"] = ["ON", True, False]
			# Same approach for the raw PID 0xD8. This corresponds to a PID 0x18
			if self.d8_alive:
					self.app.status["alive"][0] = "ON"
			else:
					self.app.status["alive"][0] = "OFF"
			self.d8_alive = False


		# major ctrl loop for inetbox-communication
		async def _lin_loop(self):
			# This is a task function running via asyncio.create_task()
			# Set timeout=1.0 when opening self.serial
			last_status_time = 0

			while True:

				# 1. Time-based status check (Uses 0% CPU compared to modulo counting)
				current_time = time.time()
				if current_time - last_status_time >= self.STATUS_INTERVAL:
						self.status_monitor_timed()
						last_status_time = current_time

				try:
					# 2. Read accumulated bytes from the OS buffer
					n = self.serial.in_waiting
					if n > 0:
							data = self.serial.read(n)
							if self.recorder:
								self.recorder.record_read(data)

							self._rx_buf.extend(data)

					if n > 0 or self.response_waiting():
						self._loop_serial()

				except Exception as e:
					# Log your error here
					await asyncio.sleep(1) # Prevent rapid looping if the USB unplugged

				if not self.stop_async :
					# Note stop_async is set to true only when writing data back.
					#self.log.debug("_lin_loop: yielding")
					# 3. Relinquish 100% of the CPU back to Venus OS.
					# 100ms sleep provides excellent responsiveness for Victron protocols
					# while keeping Cerbo GX CPU usage at absolute 0%.
					await asyncio.sleep(0.1)

		def _loop_serial(self):

			while True:
				# Find sync 0x00 0x55
				sync_idx = self._rx_buf.find(b'\x00\x55')
				if sync_idx < 0:
					self.log.debug(f"[LIN-DEBUG] No sync found, buffer: {self._rx_buf.hex(' ')}")
					# Keep last 0x00 in case sync starts there
					self._rx_buf = self._rx_buf[-1:] if self._rx_buf[-1:] == b'\x00' else bytearray()
					self.log.debug(f"[LIN-DEBUG] Kept for next iteration: {self._rx_buf.hex(' ')}")
					return

				self.log.debug(f"[LIN-DEBUG] Sync found at index {sync_idx}")

				# Need at least 3 bytes for raw PID
				if len(self._rx_buf) < sync_idx + 3:
					self.log.debug(f"[LIN-DEBUG] Need 3 bytes, have {len(self._rx_buf) - sync_idx}")
					return

				raw_pid = self._rx_buf[sync_idx + 2]

				# Determine required frame length
				frame_len = 3 if raw_pid in (0xD8, 0x7D) else 12
				if len(self._rx_buf) < sync_idx + frame_len:
					self.log.debug(f"[LIN-DEBUG] Need {frame_len} bytes, have {len(self._rx_buf) - sync_idx}")
					return

				line = bytes(self._rx_buf[sync_idx:sync_idx + frame_len])
				self.log.debug(f"[LIN-DEBUG] Full frame received: {line.hex(' ')} ({len(line)} bytes)")
				del self._rx_buf[:sync_idx + frame_len]

				self._process_frame(line)

		def _process_frame(self, line: bytes):
			self.log.debug(f"[LIN-DEBUG] Processing frame: {line.hex(' ')}")
			raw_pid = line[2]
			if raw_pid == 0xd8:
				self.d8_alive = True
				self.app.status["alive"] = ["ON", True, False]

				s = False
				if not(self.app.upload_wait):
								s = (self.app.upload_buffer or self.app.upload02_buffer)
				if s:
					self.app.upload_wait = 4
					self.stop_async = True
					self.log.debug("0x18 - update-requested")
					self._send_answer(bytearray.fromhex("ff ff ff ff ff ff ff ff 27".replace(" ","")))
					return
				else:
					self._send_answer(bytearray.fromhex("fe ff ff ff ff ff ff ff 28".replace(" ","")))
					if self.app.upload_wait:
						self.app.upload_wait -= 1
					return

			if raw_pid == 0x7d:
				if self.response_waiting():
					self.log.debug(f"_answer_tl_request")
					self._answer_tl_request()
				return

			# Remaining logic expects 12‑byte frames
			self.cnt_rows += 1
			self.cnt_rows = self.cnt_rows % self.CNT_ROWS_MAX
			if not(self.cnt_rows):
				self.display_status()

			buf_trans_id = bytes([0x00, 0x55, 0x3c, 0x03])
			if (line[:4]==buf_trans_id) and (line[4] in range(0x21, 0x27)):
				self.cpp_in_buffer[line[4] - 0x21] = line[5:-1]
				if (line[4] == 0x26):
					if (self.assemble_cpp_buffer()):
						self.prepare_tl_str_response("03 01 fb ff ff ff ff ff 00", "_send ackn-response for buffer delivery")
					return
				else:
					return

			cmd = line.hex(" ")
			cmd_ctrl = {
				"00 55 3c 7f 06 b2 00 17 46 00 1f 4b": [self.prepare_tl_str_response, "03 06 f2 17 46 00 1f 00 87", "_B2 - response request"],
				"00 55 03 aa 0a ff ff ff ff ff ff 48": [self.no_answer, "", "_NAD 03 response - ack"],
				"00 55 3c 03 06 b2 20 17 46 00 1f a7": [self.prepare_tl_str_response, "03 06 f2 17 46 00 1f 00 87", "B2 - identifier for NAD 03"],
				"00 55 3c 03 06 b2 22 17 46 00 1f a5": [self.prepare_tl_str_response, "03 06 f2 17 46 00 1f 00 87", "B2 - initializer for NAD 03   -----------------> start registration"],
				"00 55 3c 7f 06 b0 17 46 00 1f 03 4a": [self.prepare_tl_str_response, "03 01 f0 ff ff ff ff ff 0b", "B0 - init finalized - send ackn ---------------> registration finalized"],
				"00 55 3c 03 05 b9 00 1f 00 00 ff 1f": [self.prepare_tl_str_response, "03 02 f9 00 ff ff ff ff 01", "_Heartbeat for NAD 03 - send response"],
				"00 55 3c 03 10 29 bb 00 1f 00 1e ca": [self.no_answer, "", "_Frame 1 of buffer-transfer (6 frames) from CPplus"],
				"00 55 3c 03 10 0b ba 00 1f 00 1e e9": [self.generate_inet_upload, "", "BA-request: upload started"],
				"00 55 03 aa 0a ff ff ff ff ff ff 48": [self.no_answer, "", "_ackn from CPplus"],
			}
			if not(cmd in cmd_ctrl.keys()):
				return

			self.log.debug(f"[LIN-DEBUG] executing command: {cmd_ctrl[cmd][2]}")
			self.log.debug(f"[LIN-DEBUG] self.app.upload_buffer={self.app.upload_buffer}")
			cmd_ctrl[cmd][0](cmd_ctrl[cmd][1], cmd_ctrl[cmd][2])
			return
