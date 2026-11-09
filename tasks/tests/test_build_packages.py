import io
import json
import os
import shutil
import subprocess
import tarfile
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class PackageBuildIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="package-build-tests-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.repo = self.base / "repo"
        self.repo.mkdir()
        (self.repo / "tasks").mkdir()
        for name in ("build-packages", "release-packages"):
            shutil.copy2(ROOT / "tasks" / name, self.repo / "tasks" / name)
        (self.repo / "tooling").mkdir()
        (self.repo / "tooling" / "gui-v2-plugin-compiler.py").write_text(
            "# fixture\n", encoding="utf-8"
        )
        (self.repo / ".gitignore").write_text(
            "/.build/\n/feeds/*\n!/feeds/release/\n", encoding="utf-8"
        )
        self.package = self.repo / "addons" / "vespera"
        control = self.package / "src" / "CONTROL" / "control"
        control.parent.mkdir(parents=True)
        control.write_text(
            "Package: vespera\nVersion: 1.2.0\n"
            "Description: test package\nArchitecture: all\n"
            "Maintainer: Test <test@example.invalid>\nSection: misc\nPriority: optional\n"
            "Source: test://package\n",
            encoding="utf-8",
        )
        output = self.package / "src" / "data" / "plugin.json.install"
        output.parent.mkdir(parents=True)
        output.write_text("original\n", encoding="utf-8")
        for path, target in (
            ("bin/vespera", "/data/apps/available/vespera/vespera"),
            (
                "etc/udev/rules.d/serial-starter.rules-50-vespera.rules",
                "/data/apps/available/vespera/conf/serial-starter.rules",
            ),
        ):
            link = self.package / "src" / path
            link.parent.mkdir(parents=True, exist_ok=True)
            link.symlink_to(target)
        external = self.package / "src-external"
        external.mkdir()
        builder = external / "build-external"
        builder.write_text(
            "#!/usr/bin/env bash\n"
            "set -eu\n"
            "if [[ ${FAIL_BUILD:-0} == 1 ]]; then echo 'fixture failure' >&2; exit 1; fi\n"
            "root=\"$(cd \"$(dirname \"$0\")/..\" && pwd)\"\n"
            "printf 'rebuilt\\n' > \"$root/src/data/plugin.json.install\"\n"
            "printf 'workspace only\\n' > \"$root/src-external/generated\"\n",
            encoding="utf-8",
        )
        builder.chmod(0o755)
        self.git("init", "-q", "-b", "develop")
        self.git("config", "user.name", "Release Test")
        self.git("config", "user.email", "release@example.invalid")
        self.git("add", ".")
        self.git("commit", "-qm", "source")
        self.remote = self.base / "remote.git"
        subprocess.run(["git", "init", "-q", "--bare", str(self.remote)], check=True)
        self.git("remote", "add", "origin", str(self.remote))
        self.git("push", "-q", "origin", "develop")

    def git(self, *args):
        return subprocess.run(
            ["git", "-C", str(self.repo), *args],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        ).stdout.strip()

    def build(self, *args, fail=False, path=None):
        env = os.environ.copy()
        env["FAIL_BUILD"] = "1" if fail else "0"
        if path is not None:
            env["PATH"] = f"{path}:{env['PATH']}"
        return subprocess.run(
            [str(self.repo / "tasks" / "build-packages"), *args],
            cwd=self.repo,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )

    def assert_package_contains_rebuilt_plugin(self, ipk):
        data = subprocess.run(
            ["ar", "p", str(ipk), "data.tar.gz"],
            check=True,
            stdout=subprocess.PIPE,
        ).stdout
        with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
            member = next(item for item in archive.getmembers() if item.name.endswith("data/plugin.json.install"))
            self.assertEqual(archive.extractfile(member).read(), b"rebuilt\n")
            for path, target in (
                ("bin/vespera", "/data/apps/available/vespera/vespera"),
                (
                    "etc/udev/rules.d/serial-starter.rules-50-vespera.rules",
                    "/data/apps/available/vespera/conf/serial-starter.rules",
                ),
            ):
                member = next(item for item in archive.getmembers() if item.name == f"./{path}")
                self.assertTrue(member.issym())
                self.assertEqual(member.linkname, target)
        self.assertEqual(
            (self.package / "src" / "data" / "plugin.json.install").read_text(encoding="utf-8"),
            "original\n",
        )
        self.assertFalse((self.package / "src-external" / "generated").exists())

    def test_release_build_is_isolated_and_stages_real_package(self):
        self.git("switch", "-q", "-c", "release")
        result = self.build("--release-only", "vespera")
        self.assertEqual(result.returncode, 0, result.stdout)
        ipk = self.repo / "feeds" / "release" / "vespera" / "vespera_1.2.0_all.ipk"
        self.assert_package_contains_rebuilt_plugin(ipk)
        self.assertIn(str(ipk.relative_to(self.repo)), self.git("diff", "--cached", "--name-only"))
        self.assertEqual(self.git("status", "--porcelain", "--", "addons"), "")
        self.assertEqual(self.git("rev-parse", "vespera/v1.2.0^{commit}"), self.git("rev-parse", "HEAD"))

    def test_failed_release_build_preserves_feed_and_can_be_retried(self):
        self.git("switch", "-q", "-c", "release")
        feed = self.repo / "feeds" / "release" / "vespera"
        feed.mkdir(parents=True)
        (feed / "Packages").write_text("", encoding="utf-8")
        self.git("add", "feeds/release")
        self.git("commit", "-qm", "initial release feed")
        failed = self.build("--release-only", "vespera", fail=True)
        self.assertNotEqual(failed.returncode, 0, failed.stdout)
        self.assertEqual((feed / "Packages").read_text(encoding="utf-8"), "")
        self.assertEqual(self.git("status", "--porcelain"), "")
        self.assertEqual(self.git("tag", "--list"), "")
        result = self.build("--release-only", "vespera")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assert_package_contains_rebuilt_plugin(feed / "vespera_1.2.0_all.ipk")

    def test_develop_build_is_isolated_and_keeps_version_stamp(self):
        result = self.build("--develop-only", "vespera")
        self.assertEqual(result.returncode, 0, result.stdout)
        packages = list((self.repo / "feeds" / "develop" / "vespera").glob("vespera_1.2.0~d*_all.ipk"))
        self.assertEqual(len(packages), 1, result.stdout)
        self.assert_package_contains_rebuilt_plugin(packages[0])

    def test_staged_debug_plugin_builds_use_control_version(self):
        compiler = self.repo / "tooling" / "gui-v2-plugin-compiler.py"
        compiler.write_text(
            "import json, pathlib, sys\n"
            "args = sys.argv\n"
            "name = args[args.index('--name') + 1]\n"
            "version = args[args.index('--version') + 1]\n"
            "pathlib.Path('output').mkdir(exist_ok=True)\n"
            "pathlib.Path('output', name + '.json').write_text(json.dumps({'version': version}))\n",
            encoding="utf-8",
        )
        for package_name, plugin_name in (("vespera", "Vespera"), ("dbus-inetbox", "Inetbox")):
            with self.subTest(package=package_name):
                package = self.repo / "addons" / package_name
                if package_name != "vespera":
                    control = package / "src" / "CONTROL" / "control"
                    control.parent.mkdir(parents=True)
                    control.write_text(
                        (self.package / "src" / "CONTROL" / "control").read_text(encoding="utf-8")
                        .replace("Package: vespera", "Package: dbus-inetbox")
                        .replace("Version: 1.2.1", "Version: 1.2.0"), encoding="utf-8",
                    )
                plugin = package / "src-external" / "gui-v2" / plugin_name
                plugin.mkdir(parents=True)
                shutil.copy2(
                    ROOT / "addons" / package_name / "src-external" / "gui-v2" / plugin_name / "build-plugin",
                    plugin / "build-plugin",
                )
                builder = package / "src-external" / "build-external"
                builder.write_text(
                    f'#!/usr/bin/env bash\nset -eu\ncd "$(dirname "$0")/gui-v2/{plugin_name}"\n./build-plugin\n',
                    encoding="utf-8",
                )
                builder.chmod(0o755)
                for version in ("1.2.0", "1.2.1"):
                    control = package / "src" / "CONTROL" / "control"
                    control.write_text(
                        control.read_text(encoding="utf-8").replace("Version: 1.2.0", f"Version: {version}"),
                        encoding="utf-8",
                    )
                    result = self.build("--develop-only", package_name)
                    self.assertEqual(result.returncode, 0, result.stdout)
                    self.assertFalse((plugin / "version").exists())
                    staged = (self.repo / ".build" / package_name / "addons" / package_name / "src" /
                              "data" / "apps" / "available" / package_name / "gui-v2" / f"{package_name}.json.install")
                    self.assertEqual(json.loads(staged.read_text(encoding="utf-8"))["version"], version)

    def test_index_failure_does_not_publish_release_feed(self):
        self.git("switch", "-q", "-c", "release")
        fake_bin = self.base / "bin"
        fake_bin.mkdir()
        indexer = fake_bin / "opkg-make-index"
        indexer.write_text("#!/bin/sh\necho 'index failure' >&2\nexit 1\n", encoding="utf-8")
        indexer.chmod(0o755)
        result = self.build("--release-only", "vespera", path=fake_bin)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("index failure", result.stdout)
        self.assertFalse((self.repo / "feeds" / "release").exists())
        self.assertEqual(self.git("status", "--porcelain"), "")
        self.assertEqual(self.git("tag", "--list"), "")
        retried = self.build("--release-only", "vespera")
        self.assertEqual(retried.returncode, 0, retried.stdout)

    def test_release_all_builds_multiple_packages_from_separate_workspaces(self):
        second = self.repo / "addons" / "dbus-inetbox"
        shutil.copytree(
            self.package, second,
            ignore=shutil.ignore_patterns("vespera", "serial-starter.rules-50-vespera.rules"),
        )
        control = second / "src" / "CONTROL" / "control"
        control.write_text(
            control.read_text(encoding="utf-8").replace("Package: vespera", "Package: dbus-inetbox"),
            encoding="utf-8",
        )
        self.git("add", "addons/dbus-inetbox")
        self.git("commit", "-qm", "add second package")
        self.git("push", "-q", "origin", "develop")
        self.git("switch", "-q", "-c", "release")
        result = self.build("--release-only", "all")
        self.assertEqual(
            result.returncode, 0,
            result.stdout + "\nDiff:\n" + self.git("diff", "--", "addons/vespera"),
        )
        self.assert_package_contains_rebuilt_plugin(
            self.repo / "feeds" / "release" / "vespera" / "vespera_1.2.0_all.ipk"
        )
        self.assertTrue(
            (self.repo / "feeds" / "release" / "addons" / "dbus-inetbox_1.2.0_all.ipk").is_file()
        )
        for tag in ("vespera/v1.2.0", "dbus-inetbox/v1.2.0"):
            self.assertEqual(self.git("rev-parse", f"{tag}^{{commit}}"), self.git("rev-parse", "HEAD"))
        self.assertEqual(self.git("status", "--porcelain", "--", "addons"), "")

    @unittest.skipUnless(
        (ROOT / "tooling" / "gui-v2-plugin-compiler.py").is_file()
        and Path("/usr/lib/qt6/bin/lupdate").is_file()
        and Path("/usr/lib/qt6/bin/lrelease").is_file()
        and Path("/usr/lib/qt6/libexec/rcc").is_file(),
        "plugin compiler and Qt6 tools required",
    )
    def test_release_ipk_contains_real_rebuilt_vespera_plugin(self):
        plugin_source = ROOT / "addons" / "vespera" / "src-external" / "gui-v2" / "Vespera"
        plugin = self.package / "src-external" / "gui-v2" / "Vespera"
        shutil.copytree(
            plugin_source, plugin,
            ignore=shutil.ignore_patterns("output", "build", "*.rcc", "*.qm"),
        )
        shutil.copy2(
            ROOT / "tooling" / "gui-v2-plugin-compiler.py",
            self.repo / "tooling" / "gui-v2-plugin-compiler.py",
        )
        builder = self.package / "src-external" / "build-external"
        builder.write_text(
            "#!/usr/bin/env bash\nset -eu\n"
            "cd \"$(dirname \"$0\")/gui-v2/Vespera\"\n"
            "./build-plugin\n",
            encoding="utf-8",
        )
        installed = self.package / "src" / "data" / "apps" / "available" / "vespera" / "gui-v2" / "vespera.json.install"
        installed.parent.mkdir(parents=True)
        installed.write_text("original\n", encoding="utf-8")
        self.git("add", "addons", "tooling")
        self.git("commit", "-qm", "add plugin sources")
        self.git("push", "-q", "origin", "develop")
        self.git("switch", "-q", "-c", "release")
        result = self.build("--release-only", "vespera")
        self.assertEqual(result.returncode, 0, result.stdout)
        ipk = self.repo / "feeds" / "release" / "vespera" / "vespera_1.2.0_all.ipk"
        payload = subprocess.run(
            ["ar", "p", str(ipk), "data.tar.gz"], check=True, stdout=subprocess.PIPE,
        ).stdout
        with tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz") as archive:
            member = next(item for item in archive.getmembers() if item.name.endswith("/gui-v2/vespera.json.install"))
            data = json.load(archive.extractfile(member))
        self.assertEqual(data["version"], "1.2.0")
        self.assertTrue(data["resource"])
        self.assertEqual(installed.read_text(encoding="utf-8"), "original\n")
        self.assertEqual(self.git("status", "--porcelain", "--", "addons"), "")


class LocaleLoaderBuildTests(unittest.TestCase):
    @unittest.skipUnless(
        Path("/opt/venus/scarthgap-arm-cortexa8hf-neon/environment-setup-cortexa8hf-neon-ve-linux-gnueabi").is_file()
        and shutil.which("cmake"),
        "Venus ARM SDK and CMake required",
    )
    def test_locale_loader_builds_into_staged_package(self):
        with tempfile.TemporaryDirectory() as temp:
            package = Path(temp) / "vespera"
            loader = package / "src-external" / "vespera-locale-loader"
            shutil.copytree(
                ROOT / "addons" / "vespera" / "src-external" / "vespera-locale-loader",
                loader,
                ignore=shutil.ignore_patterns("build"),
            )
            translations = package / "src-external" / "gui-v2" / "Vespera" / "translations"
            translations.mkdir(parents=True)
            (translations / "Vespera_en.qm").write_bytes(b"test translation")
            output = package / "src" / "opt" / "victronenergy" / "gui" / "qml" / "Vespera"
            output.mkdir(parents=True)
            (output / "libvesperalocale.so").write_bytes(b"old library")

            result = subprocess.run(
                [str(loader / "build-locale-loader")],
                cwd=package,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
            )
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertEqual((output / "libvesperalocale.so").read_bytes()[:4], b"\x7fELF")
            self.assertEqual((output / "qmldir").read_text(), (loader / "qmldir").read_text())
            self.assertEqual((output / "lang" / "Vespera_en.qm").read_bytes(), b"test translation")


class PluginBuildTests(unittest.TestCase):
    def test_both_plugins_use_control_version_for_all_builds(self):
        for package, plugin, folder in (
            ("vespera", "Vespera", "vespera"),
            ("dbus-inetbox", "Inetbox", "dbus-inetbox"),
        ):
            with self.subTest(package=package), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                plugin_dir = root / "addons" / package / "src-external" / "gui-v2" / plugin
                plugin_dir.mkdir(parents=True)
                shutil.copy2(
                    ROOT / "addons" / package / "src-external" / "gui-v2" / plugin / "build-plugin",
                    plugin_dir / "build-plugin",
                )
                control = root / "addons" / package / "src" / "CONTROL" / "control"
                control.parent.mkdir(parents=True)
                control.write_text("Package: test\nVersion: 0.1.7\n", encoding="utf-8")
                compiler = root / "compiler.py"
                compiler.write_text(
                    "import json, pathlib, sys\n"
                    "args = sys.argv\n"
                    "name = args[args.index('--name') + 1]\n"
                    "version = args[args.index('--version') + 1]\n"
                    "output = pathlib.Path('output')\n"
                    "output.mkdir(exist_ok=True)\n"
                    "(output / (name + '.json')).write_text(json.dumps({'version': version}))\n",
                    encoding="utf-8",
                )
                env = os.environ.copy()
                env["GUI_V2_PLUGIN_COMPILER"] = str(compiler)
                env.pop("BUILD_TYPE", None)
                installed = root / "addons" / package / "src" / "data" / "apps" / "available" / folder / "gui-v2" / f"{folder}.json.install"
                for build_type in ("release", None, "debug", "release"):
                    if build_type is None:
                        env.pop("BUILD_TYPE", None)
                    else:
                        env["BUILD_TYPE"] = build_type
                    result = subprocess.run(
                        [str(plugin_dir / "build-plugin")],
                        cwd=plugin_dir,
                        env=env,
                        text=True,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT,
                    )
                    self.assertEqual(result.returncode, 0, result.stdout)
                    self.assertFalse((plugin_dir / "version").exists())
                    self.assertEqual(json.loads(installed.read_text(encoding="utf-8"))["version"], "0.1.7")
                control.write_text("Package: test\nVersion: 0.1.8\n", encoding="utf-8")
                result = subprocess.run(
                    [str(plugin_dir / "build-plugin")], cwd=plugin_dir, env=env,
                    text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                )
                self.assertEqual(result.returncode, 0, result.stdout)
                self.assertEqual(json.loads(installed.read_text(encoding="utf-8"))["version"], "0.1.8")
                self.assertFalse((plugin_dir / "version").exists())

    @unittest.skipUnless(
        (ROOT / "tooling" / "gui-v2-plugin-compiler.py").is_file()
        and Path("/usr/lib/qt6/bin/lupdate").is_file()
        and Path("/usr/lib/qt6/bin/lrelease").is_file()
        and Path("/usr/lib/qt6/libexec/rcc").is_file(),
        "plugin compiler and Qt6 tools required",
    )
    def test_real_vespera_compiler_runs_in_copied_tree(self):
        with tempfile.TemporaryDirectory() as temp:
            package = Path(temp) / "addons" / "vespera"
            plugin = package / "src-external" / "gui-v2" / "Vespera"
            shutil.copytree(
                ROOT / "addons" / "vespera" / "src-external" / "gui-v2" / "Vespera",
                plugin,
                ignore=shutil.ignore_patterns("output", "build", "*.rcc", "*.qm"),
            )
            control = package / "src" / "CONTROL" / "control"
            control.parent.mkdir(parents=True)
            control.write_text("Version: 0.1.7\n", encoding="utf-8")
            env = os.environ.copy()
            env["GUI_V2_PLUGIN_COMPILER"] = str(ROOT / "tooling" / "gui-v2-plugin-compiler.py")
            result = subprocess.run(
                [str(plugin / "build-plugin")],
                cwd=plugin,
                env=env,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
            )
            self.assertEqual(result.returncode, 0, result.stdout)
            installed = package / "src" / "data" / "apps" / "available" / "vespera" / "gui-v2" / "vespera.json.install"
            data = json.loads(installed.read_text(encoding="utf-8"))
            self.assertEqual(data["version"], "0.1.7")
            self.assertTrue(data["resource"])


if __name__ == "__main__":
    unittest.main()
