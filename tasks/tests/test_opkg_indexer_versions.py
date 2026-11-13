import itertools
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "addons/vespera/src-external/opkg-json-indexer/opkg-json-indexer.c"


@unittest.skipUnless(shutil.which("gcc") and shutil.which("opkg-compare-versions"),
                     "gcc and opkg-compare-versions are required")
class IndexerVersionTests(unittest.TestCase):
    def test_comparison_matches_opkg(self):
        versions = [
            "0.1.14", "0.2.0~261113.1100", "0.2.0~b261113.1219",
            "0.2.0~b261115.1420", "0.2.0~rc261116.1320",
            "0.2.0~rc261117.1000", "0.2.0", "0.2.0-1", "0.2.0-10",
            "1:0.1.0", "1.0", "1.00", "1.0+git1", "1.0~d123",
        ]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            harness = root / "compare.c"
            harness.write_text(
                '#define main indexer_main\n'
                f'#include "{SOURCE}"\n'
                '#undef main\n'
                'int main(int argc, char **argv) { '
                'return argc != 3 || !version_greater_than(argv[1], argv[2]); }\n'
            )
            binary = root / "compare"
            subprocess.run(["gcc", "-Wall", "-Wextra", "-o", str(binary), str(harness)], check=True)
            for candidate, installed in itertools.product(versions, repeat=2):
                expected = subprocess.run(
                    ["opkg-compare-versions", candidate, ">>", installed],
                    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                )
                self.assertIn(expected.returncode, (0, 1), expected.stderr)
                actual = subprocess.run([str(binary), candidate, installed])
                self.assertEqual(actual.returncode, expected.returncode, (candidate, installed))

    def test_package_index_reports_upgrade_only_for_newer_versions(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binary = root / "indexer"
            subprocess.run(["gcc", "-Wall", "-Wextra", "-o", str(binary), str(SOURCE)], check=True)
            lists = root / "lists"
            lists.mkdir()
            info = root / "info"
            info.mkdir()
            status = root / "status"
            config = root / "opkg.conf"
            config.write_text(
                f"option lists_dir {lists}\noption info_dir {info}\n"
                f"option status_file {status}\nsrc/gz vespera https://example.invalid\n"
            )
            for installed, candidate, expected in (
                ("0.1.14", "0.2.0~b261113.1219", "0.2.0~b261113.1219"),
                ("0.2.0~b261115.1420", "0.2.0~rc261116.1320", "0.2.0~rc261116.1320"),
                ("0.2.0~rc261116.1320", "0.2.0", "0.2.0"),
                ("0.2.0", "0.2.0~rc261116.1320", ""),
            ):
                with self.subTest(installed=installed, candidate=candidate):
                    status.write_text(
                        f"Package: vespera\nVersion: {installed}\nStatus: install ok installed\n\n"
                    )
                    (lists / "vespera").write_text(f"Package: vespera\nVersion: {candidate}\n\n")
                    subprocess.run([str(binary), str(config), str(root), "--update=all"], check=True)
                    entry = json.loads((root / "packages.json").read_text())[0]
                    self.assertEqual(entry["availableVersion"] + entry["availableVersionSuffix"], expected)
                    self.assertEqual(entry["installedVersion"] + entry["installedVersionSuffix"], installed)
