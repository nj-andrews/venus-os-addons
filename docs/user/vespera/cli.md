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
        feed <subcommand> ...         Manage active feed configurations
        device <subcommand> ...       Device discovery and binding actions
        fs-ro|fs-rw                   Remount the fs as read-only|read-write
        overlays [mount|unmount]      Mount/Unmount overlays. (or lists overlays when no args)
        enable [app ...]              Enable matching installed apps (or all when no args)
        disable [app ...]             Disable matching enabled apps (or all when no args)
        update                        Update package metadata and regenerate indexes

Feed family:
        feed                          Print active feed config name
        feed list                     Prints a list of available feed configs
        feed set                      Sets the active feed
        feed add                      Adds a new feed config
        feed remove                   Removes a feed config

  feed sources                         Show a list of the feed sources feom the active feed.
        feed add-source <name> <url>         Add a feed entry to the active feed
        feed edit-source <name> <url> [old]  Edit feed URL, optionally rename from [old]
        feed remove-source <name>            Remove a feed entry from the active feed

Device family:
        device scan                   Discover available serial devices
        device bind <tty> <svc>       Bind a serial device to service template <svc>
        device unbind <tty|sid>       Remove one binding by tty port or device sid
        device remove <sid>           Alias of device unbind
        device unbind-all <dbus-name> Remove all bindings for a dbus service
        device remove-all <dbus-name> Alias of device unbind-all

Examples:
        vespera feed set develop
        vespera feed add-source myfeed https://example.invalid/feed
        vespera device bind ttyUSB0 dbus-serialbattery
        vespera device unbind 8f9a3c12

Notes:
        Any arguments not handled above are passed directly to opkg.
```

## Notes
if you disable vespera itself using
```
vespera disable vespera
```
Global usage of the vespera command will go away.
to call vespera commands while disabled you need to call vespera directly. For example:
```
/data/apps/available/vespera/vespera [commaand]
```
---
#### Previous - [Usage](usage.md)
