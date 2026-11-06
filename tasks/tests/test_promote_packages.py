import hashlib
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from importlib.machinery import SourceFileLoader


MODULE_PATH = Path(__file__).resolve().parents[1] / "promote-packages"
SPEC = importlib.util.spec_from_loader(
    "promote_packages", SourceFileLoader("promote_packages", str(MODULE_PATH))
)
promoter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(promoter)


def build_ipk(feed_path, name, version, architecture="all", depends=None, payload=b"tested"):
    source = feed_path.parent / f"source-{name}-{version}-{architecture}"
    control_dir = source / "CONTROL"
    data_dir = source / "data"
    control_dir.mkdir(parents=True)
    data_dir.mkdir(parents=True)
    fields = [
        f"Package: {name}",
        f"Version: {version}",
        "Description: test package",
        f"Architecture: {architecture}",
        "Maintainer: Test <test@example.invalid>",
        "Section: misc",
        "Priority: optional",
        "Source: test://package",
    ]
    if depends:
        fields.append(f"Depends: {depends}")
    (control_dir / "control").write_text("\n".join(fields) + "\n", encoding="utf-8")
    (data_dir / "payload").write_bytes(payload)
    feed_path.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["opkg-build", "-o", "root", "-g", "root", str(source), str(feed_path)],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    return feed_path / f"{name}_{version}_{architecture}.ipk"


def archive_member(ipk, member):
    return subprocess.run(
        ["ar", "p", str(ipk), member],
        check=True,
        stdout=subprocess.PIPE,
    ).stdout


class PromotePackagesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="promote-packages-tests-")
        self.root = Path(self.temp.name)
        self.feeds = self.root / "feeds"
        self.develop = self.feeds / "develop"
        self.release = self.feeds / "release"
        self.staging = self.feeds / ".release-staging"
        self.backup = self.feeds / ".release-previous"
        self.archive = self.feeds / ".release-archive"
        self.lock = self.feeds / ".package-operations.lock"
        self.feeds.mkdir()
        self.constants = {
            "FEEDS": promoter.FEEDS,
            "DEVELOP": promoter.DEVELOP,
            "RELEASE": promoter.RELEASE,
            "STAGING": promoter.STAGING,
            "BACKUP": promoter.BACKUP,
            "ARCHIVE": promoter.ARCHIVE,
            "LOCK": promoter.LOCK,
        }
        for key, value in {
            "FEEDS": self.feeds,
            "DEVELOP": self.develop,
            "RELEASE": self.release,
            "STAGING": self.staging,
            "BACKUP": self.backup,
            "ARCHIVE": self.archive,
            "LOCK": self.lock,
        }.items():
            setattr(promoter, key, value)

    def tearDown(self):
        for key, value in self.constants.items():
            setattr(promoter, key, value)
        self.temp.cleanup()

    def add_candidate(self, name="vespera", version="1.2.0~d261106.1007", depends=None):
        feed = self.develop / ("vespera" if name == "vespera" else "addons")
        ipk = build_ipk(feed, name, version, depends=depends)
        metadata_dir = feed / ".metadata"
        metadata_dir.mkdir(parents=True, exist_ok=True)
        manifest = {
            "architecture": "all",
            "filename": ipk.name,
            "package": name,
            "sha256": promoter.sha256(ipk),
            "source_commit": "0123456789abcdef0123456789abcdef01234567",
            "source_dirty": False,
            "source_version": version,
        }
        (metadata_dir / f"{ipk.name}.json").write_text(
            json.dumps(manifest), encoding="utf-8"
        )
        return ipk

    def test_release_version_extracts_develop_suffix(self):
        self.assertEqual("1.10.0", promoter.release_version("1.10.0~d261106.1007"))
        self.assertGreater(promoter.version_key("1.10.0"), promoter.version_key("1.9.9"))
        with self.assertRaises(promoter.PromotionError):
            promoter.release_version("1.2")

    def test_dependency_retention_keeps_pinned_version_and_arch_variants(self):
        packages = []
        for version in ("1.0.0", "1.1.0", "1.2.0", "1.3.0", "1.4.0"):
            for architecture in (("all", "arm") if version == "1.4.0" else ("all",)):
                packages.append(
                    {
                        "path": Path(f"/unused/libfoo_{version}_{architecture}.ipk"),
                        "feed": "addons",
                        "fields": {
                            "Package": "libfoo",
                            "Version": version,
                            "Architecture": architecture,
                            "Depends": "",
                        },
                        "version": version,
                    }
                )
        app = {
            "path": Path("/unused/client_1.0.0_all.ipk"),
            "feed": "addons",
            "fields": {
                "Package": "client",
                "Version": "1.0.0",
                "Architecture": "all",
                "Depends": "libfoo (= 1.0.0)",
            },
            "version": "1.0.0",
        }
        packages.append(app)
        packages.extend(
            {
                "path": Path(f"/unused/vespera_{version}_all.ipk"),
                "feed": "vespera",
                "fields": {
                    "Package": "vespera",
                    "Version": version,
                    "Architecture": "all",
                    "Depends": "",
                },
                "version": version,
            }
            for version in ("1.0.0", "1.1.0", "1.2.0", "1.3.0")
        )
        retained, pruned = promoter.apply_retention(packages, 3)
        retained_versions = {
            package["version"]
            for package in retained
            if package["fields"]["Package"] == "libfoo"
        }
        self.assertEqual({"1.0.0", "1.2.0", "1.3.0", "1.4.0"}, retained_versions)
        self.assertEqual(
            {"all", "arm"},
            {
                package["fields"]["Architecture"]
                for package in retained
                if package["fields"]["Package"] == "libfoo"
                and package["version"] == "1.4.0"
            },
        )
        self.assertEqual(
            ["libfoo_1.1.0_all.ipk", "vespera_1.0.0_all.ipk"],
            [package["path"].name for package in pruned],
        )
        selected_retained, selected_pruned = promoter.apply_retention(
            packages, 3, ("addons",)
        )
        self.assertEqual(4, len([
            package
            for package in selected_retained
            if package["feed"] == "vespera"
        ]))
        self.assertEqual(
            ["libfoo_1.1.0_all.ipk"],
            [package["path"].name for package in selected_pruned],
        )

    def test_release_ipk_changes_version_without_changing_tested_data_archive(self):
        source = self.add_candidate()
        output = self.root / "released.ipk"
        source_data = hashlib.sha256(archive_member(source, "data.tar.gz")).hexdigest()
        promoter.create_release_ipk(source, "1.2.0", output)
        self.assertEqual(
            source_data,
            hashlib.sha256(archive_member(output, "data.tar.gz")).hexdigest(),
        )
        self.assertEqual("1.2.0", promoter.get_package_fields(output)["Version"])

    def test_build_manifest_records_commit_dirty_state_and_checksum(self):
        repository = self.root / "repo"
        package_root = repository / "addons" / "vespera"
        source_file = package_root / "src" / "payload"
        source_file.parent.mkdir(parents=True)
        source_file.write_text("committed source\n", encoding="utf-8")
        subprocess.run(["git", "init", "-q", str(repository)], check=True)
        subprocess.run(
            ["git", "-C", str(repository), "config", "user.email", "test@example.invalid"],
            check=True,
        )
        subprocess.run(
            ["git", "-C", str(repository), "config", "user.name", "Test"],
            check=True,
        )
        subprocess.run(["git", "-C", str(repository), "add", "addons/vespera"], check=True)
        subprocess.run(["git", "-C", str(repository), "commit", "-qm", "test source"], check=True)

        feed = self.develop / "vespera"
        ipk = build_ipk(feed, "vespera", "1.2.0~d261106.1007")
        promoter.write_build_manifest(package_root, feed)
        manifest_path = feed / ".metadata" / f"{ipk.name}.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        self.assertEqual(promoter.sha256(ipk), manifest["sha256"])
        self.assertFalse(manifest["source_dirty"])

        source_file.write_text("uncommitted source\n", encoding="utf-8")
        promoter.write_build_manifest(package_root, feed)
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        self.assertTrue(manifest["source_dirty"])

    def test_dry_run_does_not_publish_and_apply_stages_and_archives_release(self):
        source = self.add_candidate()
        data_hash = hashlib.sha256(archive_member(source, "data.tar.gz")).hexdigest()
        promoter.promote("vespera", False)
        self.assertFalse(self.release.exists())
        self.assertFalse(self.staging.exists())

        promoter.promote("vespera", True)
        release_package = self.release / "vespera" / "vespera_1.2.0_all.ipk"
        self.assertTrue(release_package.is_file())
        self.assertTrue((self.release / ".promotion-manifest.jsonl").is_file())
        self.assertTrue((self.release / "vespera" / "Packages.gz").is_file())
        archived_package = self.archive / "vespera" / "vespera" / release_package.name
        self.assertTrue(archived_package.is_file())
        self.assertEqual(
            data_hash,
            hashlib.sha256(archive_member(release_package, "data.tar.gz")).hexdigest(),
        )
        promoter.promote("vespera", True)
        self.assertEqual([release_package], list((self.release / "vespera").glob("*.ipk")))

    def test_release_index_lists_every_retained_version(self):
        self.add_candidate(version="1.2.0~d261106.1007")
        promoter.promote("vespera", True)
        self.add_candidate(version="1.3.0~d261107.1007")
        promoter.promote("vespera", True)
        feed = self.release / "vespera"
        index = (feed / "Packages").read_text(encoding="utf-8")
        self.assertIn("Filename: vespera_1.2.0_all.ipk", index)
        self.assertIn("Filename: vespera_1.3.0_all.ipk", index)
        self.assertFalse((feed / "Packages.stamps").exists())

    def test_unsatisfied_dependency_prevents_apply(self):
        self.add_candidate("addon", "1.2.0~d261106.1007", "vespera (>= 2.0.0)")
        with self.assertRaises(promoter.PromotionError):
            promoter.promote("addons", True)
        self.assertFalse(self.release.exists())

    def test_failed_validation_leaves_existing_release_untouched(self):
        release_feed = self.release / "vespera"
        existing = build_ipk(release_feed, "vespera", "1.1.0")
        existing_bytes = existing.read_bytes()
        self.add_candidate("addon", "1.2.0~d261106.1007", "vespera (>= 2.0.0)")

        with self.assertRaises(promoter.PromotionError):
            promoter.promote("addons", True)

        self.assertEqual(existing_bytes, existing.read_bytes())
        self.assertFalse(self.staging.exists())


if __name__ == "__main__":
    unittest.main()
