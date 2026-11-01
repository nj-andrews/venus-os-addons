import serial
import time
import logging

import serial.rs485
 
class ne_shunt_serial_service:
	
	SERIAL_BAUD_RATE = 38400
	_readonly = False
  
	_idle = bytes(    [0xff, 0x40, 0x00, 0x80, 0xbf])    #FF400080BF
	#_idle2 = bytes(  [0xff, 0x40, 0x00, 0x80, 0xbf])    #FF400080BF
	_lightin = bytes( [0xff, 0x01, 0x00, 0xc0, 0xc0])    #FF0100C0C0 
	_lightout = bytes([0xff, 0x02, 0x00, 0xc0, 0xc1])    #FF0200C0C1 
	_pump = bytes(    [0xff, 0x04, 0x00, 0xc0, 0xc3])    #FF0400C0C3 
	_aux = bytes( [0xff, 0x08, 0x00, 0xc0, 0xc7])        #FF0080C0C7  
 
	_allOff = bytes(  [0xff, 0x80, 0x00, 0xc0, 0x7f])    #FF8000007F
 
	def __init__(self, port_name, readonly):
		self._readonly=readonly
 
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
		if (name == "InternalLights"):
			self._send_data(self._lightin)
			return True
		elif (name == "ExternalLights"):
			self._send_data(self._lightout)
			return True
		elif (name == "WaterPump"):
			self._send_data(self._pump)
			return True
		elif (name == "Aux"):
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
		time.sleep(0.1)
 
	def read_data(self) -> str:
 
		if not self.serial_port.is_open:
			self.serial_port.open()
			if not self.serial_port.is_open:
				return ""
 
		BUFFER_LENGTH = 20
		CHECKSUM_LENGTH = 2
		CHECKSUM_MOD = 128
		MAX_BYTES_READ = BUFFER_LENGTH * 3

		buffer_index = 0
		buffer_all_index = 0
		bytes_read = 0
		checksum_match = False
		buffer = bytearray(BUFFER_LENGTH)
		buffer_all = bytearray(MAX_BYTES_READ)
 
		buffer[:] = b'\x00' * BUFFER_LENGTH
		buffer_all[:] = b'\x00' * MAX_BYTES_READ
 
		#self._send_idle()
		# Only reset the input buffer when absolutly nessasery
		# currently this is only done after writing data
		# This keeps the cpu % very low (under 1% otherwise can be as high as 7%)
		#self.reset_input_buffer()

		while not checksum_match:
 
			time.sleep(0.1)
			
			if self.serial_port.in_waiting > 0:
				#print("in waiting:", self.serial_port.in_waiting)
				next_byte = self.serial_port.read(1)
				if not next_byte:
					logging.debug("no byte read:")
					continue

				buffer[buffer_index] = next_byte[0]
				buffer_all[buffer_all_index] = next_byte[0]
				buffer_all_index += 1
				bytes_read += 1
				buffer_index += 1
			
			if buffer_index >= BUFFER_LENGTH:
				calced_checksum = sum(buffer[:BUFFER_LENGTH - CHECKSUM_LENGTH]) % CHECKSUM_MOD
				received_checksum = ((buffer[BUFFER_LENGTH - 2] << 8) | buffer[BUFFER_LENGTH - 1]) % CHECKSUM_MOD
				checksum_match = (calced_checksum == received_checksum - 2)

				if checksum_match and buffer[0] == 255 and buffer[14] == 255:
					res = self.byte_array_to_string(buffer)
					#logging.debug("Success, read:" + res)
					
					return res
				else:
					buffer_index -= 1
					buffer[:BUFFER_LENGTH - 1] = buffer[1:BUFFER_LENGTH]
					buffer[BUFFER_LENGTH - 1] = 0

			if bytes_read >= MAX_BYTES_READ:
				logging.debug("Timeout, read:" + self.byte_array_to_string(buffer_all))
				return ""
			elif bytes_read == 0:
				return ""
  
		return ""

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

