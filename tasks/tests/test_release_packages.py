import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path
from importlib.machinery import SourceFileLoader
from unittest.mock import patch


MODULE_PATH = Path(__file__).resolve().parents[1] / "release-packages"
SPEC = importlib.util.spec_from_loader(
    "release_packages", SourceFileLoader("release_packages", str(MODULE_PATH))
)
release_packages = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release_packages)


class ReleasePackagesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="release-packages-tests-")
        self.root = Path(self.temp.name)
        self.previous_root = release_packages.ROOT
        self.previous_release = release_packages.RELEASE
        release_packages.ROOT = self.root
        release_packages.RELEASE = self.root / "feeds" / "release"

    def tearDown(self):
        release_packages.ROOT = self.previous_root
        release_packages.RELEASE = self.previous_release
        self.temp.cleanup()

    def run_git(self, *args, check=True):
        return subprocess.run(
            ["git", "-C", str(self.root), *args],
            check=check,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        ).stdout.strip()

    def make_git_repo(self):
        subprocess.run(["git", "init", "-q", "-b", "develop", str(self.root)], check=True)
        self.run_git("config", "user.name", "Release Test")
        self.run_git("config", "user.email", "release@example.invalid")
        (self.root / ".gitignore").write_text(
            "/feeds/*\n!/feeds/release/\n", encoding="utf-8"
        )
        control = self.root / "addons" / "vespera" / "src" / "CONTROL" / "control"
        control.parent.mkdir(parents=True)
        control.write_text(
            "Package: vespera\nVersion: 1.2.0\nArchitecture: all\n",
            encoding="utf-8",
        )
        self.run_git("add", ".gitignore", "addons")
        self.run_git("commit", "-qm", "source")

        remote = self.root.parent / f"{self.root.name}-remote.git"
        subprocess.run(["git", "init", "-q", "--bare", str(remote)], check=True)
        self.run_git("remote", "add", "origin", str(remote))
        self.run_git("push", "-q", "-u", "origin", "develop")
        self.run_git("switch", "-q", "-c", "release")
        self.run_git("push", "-q", "-u", "origin", "release")
        return control

    def test_package_version_is_compared_to_latest_index_entry(self):
        control = self.root / "addons" / "vespera" / "src" / "CONTROL" / "control"
        control.parent.mkdir(parents=True)
        control.write_text("Package: vespera\nVersion: 1.3.0\n", encoding="utf-8")
        packages = self.root / "feeds" / "release" / "vespera" / "Packages"
        packages.parent.mkdir(parents=True)
        packages.write_text(
            "Package: vespera\nVersion: 1.2.0\n\n"
            "Package: vespera\nVersion: 1.1.0\n",
            encoding="utf-8",
        )
        with patch.object(
            release_packages,
            "compare_versions",
            side_effect=lambda left, operator, right: tuple(map(int, left.split(".")))
            > tuple(map(int, right.split("."))),
        ):
            self.assertTrue(
                release_packages.package_is_newer(
                    control.parents[2], packages.parent
                )
            )
            control.write_text("Package: vespera\nVersion: 1.2.0\n", encoding="utf-8")
            self.assertFalse(
                release_packages.package_is_newer(
                    control.parents[2], packages.parent
                )
            )

    def test_release_commit_and_tags_are_local_and_point_to_feed_commit(self):
        control = self.make_git_repo()
        feed = release_packages.RELEASE / "vespera"
        feed.mkdir(parents=True)
        (feed / "Packages").write_text(
            "Package: vespera\nVersion: 1.2.0\nArchitecture: all\n",
            encoding="utf-8",
        )
        (feed / "vespera_1.2.0_all.ipk").write_bytes(b"package bytes")

        release_packages.finish_release([control.parents[2]])

        commit = self.run_git("rev-parse", "HEAD")
        self.assertIn("feeds/release/vespera/Packages", self.run_git("show", "--pretty=", "--name-only"))
        self.assertEqual(self.run_git("rev-parse", "vespera/v1.2.0^{commit}"), commit)
        self.assertTrue(self.run_git("tag", "--list", "release-*"))
        remote = self.root.parent / f"{self.root.name}-remote.git"
        remote_release = subprocess.run(
            ["git", "--git-dir", str(remote), "rev-parse", "refs/heads/release"],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
        ).stdout.strip()
        self.assertNotEqual(remote_release, commit)

    def test_release_build_requires_release_branch(self):
        self.make_git_repo()
        self.run_git("switch", "-q", "develop")
        with self.assertRaisesRegex(release_packages.ReleaseBuildError, "requires the release branch"):
            release_packages.validate_release_state(require_clean=True)

    def test_release_must_include_latest_develop_commit(self):
        self.make_git_repo()
        self.run_git("switch", "-q", "develop")
        (self.root / "source-update").write_text("new source\n", encoding="utf-8")
        self.run_git("add", "source-update")
        self.run_git("commit", "-qm", "new develop source")
        self.run_git("push", "-q", "origin", "develop")
        self.run_git("switch", "-q", "release")
        with self.assertRaisesRegex(release_packages.ReleaseBuildError, "does not include"):
            release_packages.validate_release_state(require_clean=True)

    def test_existing_package_tag_stops_before_feed_commit(self):
        control = self.make_git_repo()
        self.run_git("tag", "-a", "vespera/v1.2.0", "-m", "already released")
        feed = release_packages.RELEASE / "vespera"
        feed.mkdir(parents=True)
        (feed / "Packages").write_text(
            "Package: vespera\nVersion: 1.2.0\nArchitecture: all\n",
            encoding="utf-8",
        )
        (feed / "vespera_1.2.0_all.ipk").write_bytes(b"package bytes")

        with self.assertRaisesRegex(release_packages.ReleaseBuildError, "already exists"):
            release_packages.finish_release([control.parents[2]])
        self.assertEqual(self.run_git("rev-parse", "HEAD"), self.run_git("rev-parse", "release"))
        self.assertEqual(self.run_git("diff", "--cached", "--name-only"), "")


if __name__ == "__main__":
    unittest.main()
