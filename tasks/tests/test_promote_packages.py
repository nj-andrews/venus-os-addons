import hashlib
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from importlib.machinery import SourceFileLoader
from unittest.mock import patch


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
        git_check = patch.object(promoter, "validate_promotion_git_state")
        git_check.start()
        self.addCleanup(git_check.stop)
        tags = patch.object(promoter, "prepare_release_tags", return_value=[("release-test", "Release")])
        tags.start()
        self.addCleanup(tags.stop)
        publish_git = patch.object(promoter, "commit_and_push_release")
        publish_git.start()
        self.addCleanup(publish_git.stop)
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


class PromotionGitStateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="promotion-git-tests-")
        self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        self.repo = base / "repo"
        self.remote = base / "origin.git"
        self.repo.mkdir()
        subprocess.run(["git", "init", "--bare", "-q", str(self.remote)], check=True)
        self.git("init", "-q")
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "user.name", "Test")
        (self.repo / "source").write_text("initial\n", encoding="utf-8")
        self.git("add", "source")
        self.git("commit", "-qm", "initial")
        self.git("branch", "develop")
        self.git("checkout", "-qb", "release")
        self.git("remote", "add", "origin", str(self.remote))
        self.git("push", "-q", "origin", "develop", "release")
        root_patch = patch.object(promoter, "ROOT", self.repo)
        root_patch.start()
        self.addCleanup(root_patch.stop)

    def git(self, *args):
        return subprocess.run(
            ["git", "-C", str(self.repo), *args],
            check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        ).stdout.strip()

    def commit_change(self):
        (self.repo / "source").write_text("changed\n", encoding="utf-8")
        self.git("add", "source")
        self.git("commit", "-qm", "change")

    def test_matching_clean_branches_are_accepted(self):
        promoter.validate_promotion_git_state()

    def test_wrong_branch_and_detached_head_are_rejected(self):
        self.git("checkout", "-q", "develop")
        with self.assertRaisesRegex(promoter.PromotionError, "requires the release branch"):
            promoter.validate_promotion_git_state()
        self.git("checkout", "-q", "--detach")
        with self.assertRaisesRegex(promoter.PromotionError, "detached HEAD"):
            promoter.validate_promotion_git_state()

    def test_dirty_tracked_staged_and_untracked_changes_are_rejected(self):
        source = self.repo / "source"
        source.write_text("changed\n", encoding="utf-8")
        with self.assertRaisesRegex(promoter.PromotionError, "clean working tree"):
            promoter.validate_promotion_git_state()
        self.git("add", "source")
        with self.assertRaisesRegex(promoter.PromotionError, "clean working tree"):
            promoter.validate_promotion_git_state()
        self.git("restore", "--staged", "--worktree", "source")
        (self.repo / "untracked").write_text("new\n", encoding="utf-8")
        with self.assertRaisesRegex(promoter.PromotionError, "clean working tree"):
            promoter.validate_promotion_git_state()

    def test_remote_develop_is_fetched_and_must_match_local_develop(self):
        self.commit_change()
        self.git("push", "-q", "origin", "HEAD:develop")
        self.git("checkout", "-q", "develop")
        self.git("branch", "-f", "release", "develop")
        self.git("checkout", "-q", "release")
        with self.assertRaisesRegex(promoter.PromotionError, "local develop does not match"):
            promoter.validate_promotion_git_state()
        self.assertNotEqual(
            self.git("rev-parse", "develop"), self.git("rev-parse", "origin/develop")
        )

    def test_local_develop_ahead_of_remote_is_rejected(self):
        self.git("checkout", "-q", "develop")
        self.commit_change()
        self.git("checkout", "-q", "release")
        with self.assertRaisesRegex(promoter.PromotionError, "local develop does not match"):
            promoter.validate_promotion_git_state()

    def test_release_must_be_exactly_develop(self):
        self.commit_change()
        with self.assertRaisesRegex(promoter.PromotionError, "same commit"):
            promoter.validate_promotion_git_state()

    def test_fetch_failure_is_reported(self):
        self.git("remote", "set-url", "origin", str(self.repo / "missing-remote"))
        with self.assertRaisesRegex(promoter.PromotionError, "command failed:.*fetch"):
            promoter.validate_promotion_git_state()

    def test_missing_local_develop_is_rejected(self):
        self.git("branch", "-D", "develop")
        with self.assertRaisesRegex(promoter.PromotionError, "refs/heads/develop"):
            promoter.validate_promotion_git_state()

    def test_apply_commits_and_pushes_annotated_tags(self):
        feeds = self.repo / "feeds"
        develop = feeds / "develop"
        release = feeds / "release"
        feed = develop / "vespera"
        feed.mkdir(parents=True)
        source = build_ipk(Path(self.temp.name) / "build", "vespera", "1.2.0~d261106.1007")
        ipk = feed / source.name
        ipk.write_bytes(source.read_bytes())
        metadata = feed / ".metadata"
        metadata.mkdir()
        (metadata / f"{ipk.name}.json").write_text(json.dumps({
            "architecture": "all",
            "filename": ipk.name,
            "package": "vespera",
            "sha256": promoter.sha256(ipk),
            "source_commit": self.git("rev-parse", "HEAD"),
            "source_dirty": False,
            "source_version": "1.2.0~d261106.1007",
        }), encoding="utf-8")
        (self.repo / ".gitignore").write_text(
            "feeds/.package-operations.lock\nfeeds/.release-staging/\nfeeds/.release-previous/\n",
            encoding="utf-8",
        )
        self.git("add", "feeds/develop", ".gitignore")
        self.git("commit", "-qm", "add development package")
        self.git("branch", "-f", "develop", "HEAD")
        self.git("push", "-q", "origin", "develop")
        monthly = "release-" + promoter.time.strftime("%Y.%m", promoter.time.gmtime())
        self.git("tag", "-a", monthly, "-m", "existing")
        self.git("push", "-q", "origin", f"refs/tags/{monthly}")
        self.git("tag", "unrelated-local")

        with patch.multiple(
            promoter,
            FEEDS=feeds,
            LOCK=feeds / ".package-operations.lock",
            DEVELOP=develop,
            RELEASE=release,
            BACKUP=feeds / ".release-previous",
            STAGING=feeds / ".release-staging",
            ARCHIVE=feeds / ".release-archive",
        ):
            promoter.promote("vespera", True)

        commit = self.git("rev-parse", "HEAD")
        snapshot = monthly + ".2"
        for tag in (snapshot, "vespera/v1.2.0"):
            self.assertEqual(self.git("cat-file", "-t", f"refs/tags/{tag}"), "tag")
            self.assertEqual(self.git("rev-parse", f"{tag}^{{commit}}"), commit)
            remote_commit = subprocess.run(
                ["git", "--git-dir", str(self.remote), "rev-parse", f"refs/tags/{tag}^{{commit}}"],
                check=True, text=True, stdout=subprocess.PIPE,
            ).stdout.strip()
            self.assertEqual(remote_commit, commit)
        self.assertEqual(
            subprocess.run(
                ["git", "--git-dir", str(self.remote), "rev-parse", "refs/heads/release"],
                check=True, text=True, stdout=subprocess.PIPE,
            ).stdout.strip(), commit,
        )
        self.assertEqual(self.git("status", "--porcelain"), "")
        self.assertIn("Co-authored-by: Copilot", self.git("show", "-s", "--format=%B", "HEAD"))
        remote_tags = subprocess.run(
            ["git", "--git-dir", str(self.remote), "tag", "--list"],
            check=True, text=True, stdout=subprocess.PIPE,
        ).stdout.splitlines()
        self.assertNotIn("unrelated-local", remote_tags)

    def test_existing_package_tag_blocks_before_release_is_published(self):
        self.git("tag", "-a", "vespera/v1.2.0", "-m", "already released")
        self.git("push", "-q", "origin", "refs/tags/vespera/v1.2.0")
        self.git("tag", "-d", "vespera/v1.2.0")
        candidate = {"fields": {"Package": "vespera"}, "version": "1.2.0"}
        with self.assertRaisesRegex(promoter.PromotionError, "already exists"):
            promoter.prepare_release_tags([candidate])

    def test_push_failure_keeps_commit_and_tags_local_with_retry_instructions(self):
        release = self.repo / "feeds" / "release"
        release.mkdir(parents=True)
        (release / "example").write_text("new release\n", encoding="utf-8")
        hook = self.remote / "hooks" / "pre-receive"
        hook.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
        hook.chmod(0o755)
        remote_before = self.git("rev-parse", "origin/release")
        tags = [("release-test", "Release test"), ("vespera/v1.2.0", "vespera v1.2.0")]
        with patch.multiple(promoter, RELEASE=release, ARCHIVE=self.repo / "feeds" / ".release-archive"):
            with self.assertRaisesRegex(promoter.PromotionError, "retry.*git push --atomic"):
                promoter.commit_and_push_release(tags)
        self.assertNotEqual(self.git("rev-parse", "HEAD"), remote_before)
        self.assertEqual(self.git("rev-parse", "release-test^{commit}"), self.git("rev-parse", "HEAD"))
        self.assertEqual(self.git("rev-parse", "origin/release"), remote_before)
        self.assertEqual(
            subprocess.run(
                ["git", "--git-dir", str(self.remote), "tag", "--list"],
                check=True, text=True, stdout=subprocess.PIPE,
            ).stdout, "",
        )

    def test_release_remote_divergence_is_rejected(self):
        self.commit_change()
        self.git("push", "-q", "origin", "release")
        self.git("checkout", "-q", "develop")
        self.git("branch", "-f", "release", "develop")
        self.git("checkout", "-q", "release")
        with self.assertRaisesRegex(promoter.PromotionError, "not an ancestor"):
            promoter.prepare_release_tags([])

    def test_preview_and_apply_accept_matching_clean_branches(self):
        feeds = Path(self.temp.name) / "feeds"
        feeds.mkdir()
        with patch.multiple(
            promoter,
            LOCK=feeds / ".lock",
            DEVELOP=feeds / "develop",
            RELEASE=feeds / "release",
            BACKUP=feeds / ".release-previous",
            STAGING=feeds / ".release-staging",
            ARCHIVE=feeds / ".release-archive",
        ):
            for apply in (False, True):
                with self.subTest(apply=apply):
                    promoter.promote("all", apply)
                    self.assertFalse((feeds / "release").exists())

    def test_preview_and_apply_check_before_recovering_or_publishing(self):
        feeds = Path(self.temp.name) / "feeds"
        feeds.mkdir()
        release = feeds / "release"
        backup = feeds / ".release-previous"
        staging = feeds / ".release-staging"
        backup.mkdir()
        self.git("checkout", "-q", "develop")
        with (
            patch.object(promoter, "LOCK", feeds / ".lock"),
            patch.object(promoter, "RELEASE", release),
            patch.object(promoter, "BACKUP", backup),
            patch.object(promoter, "STAGING", staging),
        ):
            for apply in (False, True):
                with self.subTest(apply=apply):
                    with self.assertRaisesRegex(promoter.PromotionError, "requires the release branch"):
                        promoter.promote("all", apply)
                    self.assertTrue(backup.is_dir())
                    self.assertFalse(release.exists())
                    self.assertFalse(staging.exists())


if __name__ == "__main__":
    unittest.main()
