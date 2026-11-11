import csv
from pathlib import Path


def _extract_error_codes(cell_value):
	if not cell_value:
		return []
	return [
		code
		for part in str(cell_value).split("|")
		if (code := part.translate(str.maketrans("", "", "WHEA")).strip())
	]


def get_error_description(error_code, csv_file=None):
	"""Return Cause text for an error code, joining multiple causes with '|'."""
	if error_code is None:
		return ""

	code = str(error_code).strip()
	if not code:
		return ""
	if code == "900":
		return "Inetbox service restarted"

	source = Path(csv_file) if csv_file else Path(__file__).with_name("truma-error-codes.csv")
	causes = []
	with open(source.resolve(), newline="", encoding="utf-8-sig") as fh:
		reader = csv.DictReader(fh)
		for row in reader:
			cause = (row.get("Cause") or "").strip()
			if not cause:
				continue

			codes = _extract_error_codes(row.get("Fault Code"))
			if code in codes and cause not in causes:
				causes.append(cause)

	return "\n".join(causes)
