# Vespera CLI

The Vespera command-line interface is installed as the `vespera` binary and provides the same package-management features as the UI, plus a few service and diagnostics helpers that are useful from SSH or scripts.

## Basic usage

```bash
vespera --help
vespera help
```

The built-in help is the authoritative reference for the current CLI and is generated from the installed script:

```text
Usage:
    vespera [options] [command] [arguments...]
    vespera [opkg-options] [opkg-args...]

Vespera options:
    --help, help                  Show this help
    -V0 .. -V4                    Set opkg verbosity level
    --in-gui                      Internal GUI mode flag

Commands:
    status                        Show Vespera status via opkg
    inspect, i [app ...]          Show app, service, addon, and dbus details
    list-enabled, le [app ...]    List enabled apps/packages
    list-services, ls [app ...]   List service status
    list-feeds                    Show the active feed file and its contents
    list-feed-sources             List feed source files
    feed [set|add|edit|remove] ...
                                  Manage the active feed configuration
    device [scan|bind|remove] ...
                                  Device-related actions
    fs-ro                         Remount the fs as read-only
    overlays [mount|unmount]
    enable [app ...]              Enable matching installed apps (or all when no args)
    disable [app ...]             Disable matching enabled apps (or all when no args)
    update                        Update package metadata and regenerate indexes

Notes:
    Any arguments not handled above are passed directly to opkg.
```

## Command reference

### help

```bash
vespera --help
vespera help
```

Prints CLI usage, top-level commands, and option summary.

### status

```bash
vespera status
```

Shows package status via `opkg status` using Vespera's combined config.

### inspect, i

```bash
vespera inspect
vespera inspect my-package
vespera i my-package
```

Displays app/service/addon/dbus details for all apps or matching app names.

### list-enabled, le

```bash
vespera list-enabled
vespera list-enabled my-package
vespera le
```

Lists enabled apps/packages. Optional arguments filter the result.

### list-services, ls

```bash
vespera list-services
vespera list-services my-package
vespera ls
```

Lists service status for all apps or matching app names.

### list-feeds

```bash
vespera list-feeds
```

Shows the currently selected feed and configured feed entries.

### list-feed-sources

```bash
vespera list-feed-sources
```

Lists available feed configurations.

### feed

```bash
vespera feed
vespera feed set my-feed
vespera feed add my-feed https://example.com/feed
vespera feed edit my-feed https://example.com/feed
vespera feed remove my-feed
```

Manages feed configuration.

`vespera feed`:
prints the active feed name.

`vespera feed set <feed-name>`:
selects the feed to use for package operations.

`vespera feed add <name> <url>`:
adds a feed entry.

`vespera feed edit <name> <url>`:
updates an existing feed entry.

`vespera feed remove <name>`:
removes a feed configuration. Removal fails when `<name>` is the currently active feed.

### device

```bash
vespera device scan
vespera device bind <device>
vespera device remove <device>
```

Runs device helper actions for USB/serial device discovery and bindings.

### fs-ro

```bash
vespera fs-ro
```

Remounts the root filesystem read-only.

### overlays

```bash
vespera overlays
vespera overlays mount
vespera overlays unmount
```

Shows overlay config, or mounts/unmounts overlays.

### enable and disable

```bash
vespera enable
vespera enable my-package
vespera disable
vespera disable my-package
```

Enables or disables matching installed apps/packages. With no arguments, applies to all matching entries.

### update

```bash
vespera update
```

Runs `opkg update` and refreshes Vespera metadata/indexes.

## Passing through to opkg

Any unrecognized Vespera command is passed directly to `opkg` with Vespera's combined config file loaded.

Examples:

```bash
vespera install my-package
vespera remove my-package
vespera upgrade my-package
vespera list
```

This means Vespera can act as a wrapper around standard `opkg` operations while also applying its own pre-install and post-install hooks.

## Script usage

Vespera is designed to be useful in scripts as well as interactive shell use. Typical patterns:

```bash
vespera update
vespera list-feeds
vespera install some-addon
vespera status
```

Use `--help` or `help` whenever you need the current CLI summary for the installed build.

---
#### Previous - [Usage](usage.md)
