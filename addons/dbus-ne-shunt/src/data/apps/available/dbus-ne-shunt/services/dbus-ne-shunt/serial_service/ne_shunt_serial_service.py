import serial
import time
import logging

import serial.rs485

class ne_shunt_serial_service:

	SERIAL_BAUD_RATE = 38400
	_readonly = False
	FRAME_LENGTH = 20

	_idle = bytes(    [0xff, 0x40, 0x00, 0x80, 0xbf])    #FF400080BF
	#_idle2 = bytes(  [0xff, 0x40, 0x00, 0x80, 0xbf])    #FF400080BF
	_lightin = bytes( [0xff, 0x01, 0x00, 0xc0, 0xc0])    #FF0100C0C0
	_lightout = bytes([0xff, 0x02, 0x00, 0xc0, 0xc1])    #FF0200C0C1
	_pump = bytes(    [0xff, 0x04, 0x00, 0xc0, 0xc3])    #FF0400C0C3
	_aux = bytes( [0xff, 0x08, 0x00, 0xc0, 0xc7])        #FF0080C0C7

	_allOff = bytes(  [0xff, 0x80, 0x00, 0xc0, 0x7f])    #FF8000007F

	def __init__(self, port_name, readonly):
		self._readonly=readonly
		self._rx_buffer = bytearray()

		self.serial_port = serial.rs485.RS485(port=port_name,
												baudrate=self.SERIAL_BAUD_RATE,
												bytesize=serial.EIGHTBITS,
												parity=serial.PARITY_NONE,
												stopbits=serial.STOPBITS_ONE,
												xonxoff=False,
												rtscts=False,
												dsrdtr=False,   # also typically off unless explicitly needed
												timeout=1    # blocking read (like raw mode)
	)

		self.serial_port.rs485_mode = serial.rs485.RS485Settings()
		#self.serial_port = serial.Serial(port=port_name, baudrate=self.SERIAL_BAUD_RATE,bytesize=8, parity="N", stopbits=1, timeout=1)

	def close(self):
		if self.serial_port.is_open:
			self.serial_port.close()

	def toggle_all_off(self):
		self._send_data(self._allOff)

	def toggle_switch(self, name):
		if (name == "internal_lights"):
			self._send_data(self._lightin)
			return True
		elif (name == "external_lights"):
			self._send_data(self._lightout)
			return True
		elif (name == "water_pump"):
			self._send_data(self._pump)
			return True
		elif (name == "aux"):
			self._send_data(self._aux)
			return True

	def _send_idle(self):
		self.serial_port.write(self._idle)
		time.sleep(0.1)

	def _send_data(self, data):

		if self._readonly == True:
			return

		self._send_idle()
		self.serial_port.write(data)
		self.serial_port.reset_input_buffer()
		self._rx_buffer.clear()
		time.sleep(0.1)

	def read_data(self) -> str:
		"""Non-blocking: returns the newest complete frame received, or "" if none yet."""

		if not self.serial_port.is_open:
			self.serial_port.open()
			if not self.serial_port.is_open:
				return ""

		waiting = self.serial_port.in_waiting
		if waiting > 0:
			self._rx_buffer += self.serial_port.read(waiting)

		buf = self._rx_buffer
		frame = None
		consumed = 0
		i = 0
		while i + self.FRAME_LENGTH <= len(buf):
			if buf[i] == 255 and buf[i + 14] == 255 and self._checksum_ok(buf, i):
				frame = bytes(buf[i:i + self.FRAME_LENGTH])
				i += self.FRAME_LENGTH
				consumed = i
			else:
				i += 1

		if frame is not None:
			del buf[:consumed]
			return self.byte_array_to_string(frame)

		# no frame: keep only a possible partial frame, bounded in size
		keep = self.FRAME_LENGTH * 3
		if len(buf) > keep:
			del buf[:len(buf) - keep]
		return ""

	def _checksum_ok(self, buf, start):
		L = self.FRAME_LENGTH
		calced = sum(buf[start:start + L - 2]) % 128
		received = ((buf[start + L - 2] << 8) | buf[start + L - 1]) % 128
		return calced == received - 2

	def _write_data(self, data):

		if self.serial_port.is_open:
			self.serial_port.write((data + '\n').encode())
		else:
			logging.error("Serial port is not open.")
			raise Exception("Serial port is not open.")

	@staticmethod
	def byte_array_to_string(byte_array):
		"""
		Converts a byte array to a hex string (e.g., b'\x01\x02' -> '0102').
		"""
		return ''.join(f'{b:02X}' for b in byte_array)
