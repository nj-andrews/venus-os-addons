# Vespera Overview
Vespera - The evening star of Venus

Vespera allows end users to install and manage `opkg` packages (add-ons) on the Venus OS without needing complex SSH shell commands. It also lets users add custom feeds for third-party add-ons and configure custom usb serial devices.

![Vespera main menu screenshot](images/vespera-home.webp "Vespera Settings")

## What is Opkg?
Opkg (Open Package Management) is a compact package manager built for embedded Linux environments and IoT devices. It is widely used in OpenWrt, smart-home controllers, and Yocto-based distributions, and it provides functionality similar to `apt` while keeping memory usage low. Opkg comes pre-installed with Venus OS.

## USB Serial Device Installer
In addition to installing add-ons, Vespera also supports installing USB serial devices and services.

After selecting the service to use and connecting a USB device, the installer detects the device and starts the appropriate service.

## New Firmware Updates
When a new Venus OS firmware version is installed, Vespera automatically downloads and reinstalls previously installed packages.

## Gui-V1
### Menu Customization

Provides add-ons with the ability to add, remove, and reposition menu entries in Venus OS without patching UI files. This is described in more detail in the developer documentation, and remains transparent to end users.

### Overview Page Customization
Provides add-ons with the ability to add, remove, or replace overview pages without patching UI files. This is also documented in the developer guides and remains transparent to end users.


## Other Features
Vespera intentionally does not use the Linux `patch` command to modify shared UI files.

While `patch` is useful during development, it is a poor fit for production installers that must behave reliably across many systems and firmware versions. Even minor upstream changes can cause a patch to fail or apply in the wrong place, and multiple add-ons patching the same file can conflict. This makes installs and updates less predictable.

The `patch` command also does not provide package-level ownership of individual changes. That means uninstall and rollback behavior is harder to guarantee, especially when several packages have touched the same shared file over time.

Instead, Vespera uses a custom `file-patcher` method for very small, controlled integration hooks usually added to the end of UI files. These hook blocks are intentionally minimal and are designed to be applied and removed cleanly during install and uninstall. This keeps updates safer and recovery behavior more predictable.

---
#### Next - [Setup](setup.md)