# Vespera example addons

Each `vespera-example-NN` directory is an independent OPKG package source. Build
packages from the repository root with:

```sh
tasks/build-packages vespera-examples/vespera-example-02 \
  vespera-examples/vespera-example-03 vespera-examples/vespera-example-04 \
  vespera-examples/vespera-example-05 vespera-examples/vespera-example-06 \
  vespera-examples/vespera-example-07 vespera-examples/vespera-example-08 \
  vespera-examples/vespera-example-09 vespera-examples/vespera-example-10
```

Examples 2–4 contain gui-v2 QML resources. Run each `build-plugin` script from
its plugin directory to compile its resource bundle before building its OPKG
package. The scripts use `tooling/gui-v2-plugin-compiler.py` from this
repository, or `GUI_V2_PLUGIN_COMPILER` if you keep the compiler elsewhere.

| Addon | Demonstration |
| --- | --- |
| [`vespera-example-01`](#vespera-example-01) | Adds custom menus to the classic GUI. |
| [`vespera-example-02`](#vespera-example-02) | Adds a classic-GUI overview page and a gui-v2 navigation page. |
| [`vespera-example-03`](#vespera-example-03) | Loads a gui-v2 plugin that displays “Hello world” and registers a navigation page. |
| [`vespera-example-04`](#vespera-example-04) | Registers a gui-v2 navigation page backed by a packaged QML resource. |
| [`vespera-example-05`](#vespera-example-05) | Runs a regular supervised service that logs every 10 seconds. |
| [`vespera-example-06`](#vespera-example-06) | Runs a USB-serial templated service that logs every 10 seconds. |
| [`vespera-example-07`](#vespera-example-07) | Publishes a simple value from a D-Bus service. |
| [`vespera-example-08`](#vespera-example-08) | Adds a QML file using a Vespera-managed overlay. |
| [`vespera-example-09`](#vespera-example-09) | Runs addon hooks when `vespera enable` and `vespera disable` commands are used. |
| [`vespera-example-10`](#vespera-example-10) | Runs separate `rcS.local` and `rc.local` hooks at boot. |

## vespera-example-01

Adds custom menus to the classic GUI.

## vespera-example-02

Adds a classic-GUI overview page and a gui-v2 navigation page. This example
includes `installer-navigation-pages` and `installer-overview-pages` sidecars.

## vespera-example-03

Loads a gui-v2 plugin that displays “Hello world” and registers a navigation
page. This example includes an `installer-navigation-pages` sidecar.

## vespera-example-04

Registers a gui-v2 navigation page backed by a packaged QML resource.

## vespera-example-05

Runs a regular supervised service that logs every 10 seconds. As a regular
service, it does not need `installer-devices`.

## vespera-example-06

Runs a USB-serial templated service that logs every 10 seconds. As a templated
service, it uses `installer-devices`.

## vespera-example-07

Publishes a simple value from a D-Bus service.

## vespera-example-08

Adds a QML file using a Vespera-managed overlay.

## vespera-example-09

Runs addon hooks when `vespera enable` and `vespera disable` commands are used.
The hooks are source files in `CONTROL`; Vespera stages them under
`/data/var/vespera/info` with the package name as a prefix.

To exercise this example on a device after installation, run:

```sh
vespera disable vespera-example-09
vespera enable vespera-example-09
```

## vespera-example-10

Runs separate `rcS.local` and `rc.local` hooks at boot. The hooks are source
files in `CONTROL`; Vespera stages them under `/data/var/vespera/info` with the
package name as a prefix. They do not edit `/data/rcS.local` or
`/data/rc.local`.

To exercise this example on a device after installation, run:

```sh
/data/rc.local
/data/rcS.local
```

Then view the startup log:

```sh
cat /var/log/vespera/rc-local.log
```