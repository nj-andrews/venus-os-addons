import os
import re


class VesperaConfig:
		"""Read the shared Vespera conf file and expose values as plain strings or resolved paths."""

		def __init__(self, config_path=None):
			self._config_path = os.path.abspath(config_path or self.default_config_path())
			self._values = self._load_config()

		@staticmethod
		def default_config_path():
			service_dir = os.path.dirname(os.path.abspath(__file__))
			path = os.path.abspath(os.path.join(service_dir, "../..", "conf", "vespera.conf"))
			return path

		@property
		def config_path(self):
			return self._config_path

		@property
		def app_root(self):
			return os.path.abspath(os.path.join(os.path.dirname(self._config_path), ".."))

		def _load_config(self):
			values = {}
			try:
				with open(self._config_path, "r", encoding="utf-8") as handle:
					for raw_line in handle:
						line = raw_line.strip()
						if not line or line.startswith("#") or "=" not in line:
							continue
						key, value = line.split("=", 1)
						# Drop inline comments ("KEY=3 # note"); '#' must be preceded by whitespace
						value = re.split(r"\s+#", value, maxsplit=1)[0]
						values[key.strip()] = value.strip()
			except OSError:
				return {}
			return values

		def get(self, key, default=None):
			return self._values.get(key, default)

		def get_path(self, key, default=None):
			value = self.get(key, default)
			if value is None:
				return None
			if os.path.isabs(value):
				return value
			return os.path.abspath(os.path.join(self.app_root, value))
