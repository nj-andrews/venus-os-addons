import copy
import logging

class ne_shunt_data:

	KEYS = [
		"fresh_water_tank", "grey_waste_tank", "grey_waste_tank2",
		"internal_lights", "external_lights", "aux", "water_pump",
		"cab_battery", "leisure_battery"
	]

	def clone(self): 
		return copy.deepcopy(self)
	
	def __init__(self, rawData = None):
		if rawData is None:
			self.data = {k: "" for k in self.KEYS}
		else:
			self.data = {
				"fresh_water_tank": self._get_tank_level(rawData[11:12]),
				"grey_waste_tank": self._get_tank_level(rawData[13:14]),
				"grey_waste_tank2": self._get_tank_level(rawData[15:16]),
				"internal_lights": self._get_indoor_light_state(rawData[31:32]),
				"external_lights": self._get_outdoor_light_state(rawData[31:32]),
				"water_pump": self._get_pump_state(rawData[31:32]),
				"aux": self._get_aux_state(rawData[31:32]),
				"cab_battery": self._get_battery_level(rawData[24:26]),
				"leisure_battery": self._get_battery_level(rawData[26:28]),
			}

	@staticmethod
	def _get_tank_level(data_part):
		val = int(data_part, 16)
		level = 0
		if val & 1: level += 1
		if val & 2: level += 1
		if val & 4: level += 1
		return str(level)

	@staticmethod
	def _get_indoor_light_state(data):
		return 1 if (int(data, 16) & 1) else 0

	@staticmethod
	def _get_outdoor_light_state(data):
		return 1 if (int(data, 16) & 2) else 0

	@staticmethod
	def _get_pump_state(data):
		return 1 if (int(data, 16) & 4) else 0
	
	@staticmethod
	def _get_aux_state(data):
		return 1 if (int(data, 16) & 8) else 0
	
	@staticmethod
	def _get_battery_level(data):
		
		encoded_voltage = int(data, 16)
		voltage = (encoded_voltage - 30) / 10
		#logging.debug("_get_battery_level: " + data + ", voltage = " + str(f"{voltage:.2f}"))
		return f"{voltage:.2f}"

	def get_value(self, name):
		"""Get the value of a specific key."""
		if name in self.KEYS:
			return self.data[name]
		else:
			raise KeyError(f"Invalid key: {name}")
		
	def diff(self, other):
		"""Yield (key, value) pairs where value differs from other."""
		for k in self.KEYS:
			if other == None or (self.data[k] != other.data[k]):
				yield k, self.data[k]