# Vespera Usage

This guide walks you through the basic use of Vespera, including how to manage packages and feeds, install USB serial devices, and safely preview changes before applying them.

For command-line usage and scripting, see the [Vespera CLI reference](cli.md).

![Vespera Settings](images/vespera-home.webp "Vespera Settings")

### Packages
Use the Packages page to install, upgrade, reinstall, or remove add-ons.

![Vespera Packages](images/packages-list.webp "Vespera Packages")

#### Typical workflow:

1. Open `Menu -> Settings -> Open Package Manager`.
2. Open the **Packages** list.
3. Select a package to view details and available actions.
4. From here you can Install,Remove or Upgrade packages.
6. Confirm the operation.

#### What to expect:

* Vespera resolves dependencies before applying changes.
* If dependencies cannot be satisfied, the operation is blocked and an error is shown.
* If the package contains Venus Intergrations, the UI may be interupted while its reloaded.

You can also Disable and Enable packages. Disablng a package, stops all its services, and disables any Venus intergrations for the package, without removing any settings.

### Feeds
Feeds are package sources. The **Feeds** page lets you manage which repositories Vespera uses.

![Vespera Feeds](images/feeds-list.webp "Vespera Feeds")

#### Common feed tasks:

* Add a feed by providing a feed name and URL.
* Enable/disable a feed to include or exclude it from package searches.
* Remove a feed that is no longer needed.
* Refresh feed indexes so the package list reflects the latest available versions.

#### Recommendations:

* Prefer trusted release feeds for stable systems.
* Use development feeds only when testing and you are prepared for breakage.
* Keep the number of active feeds minimal to reduce conflicts between package versions.

### Custom Devices.
The Custom Devices paged helps to bind supported USB serial devices to a selected service.

![Custom devices](images/custom-devices.webp "Custom devices screenshot")
#### Basic usage:

1. Ensure the usb serial device to use is connected via a USB port
2. Install the package that supports the device you want to bind to. ie. dbus-inetbox. Read any documentation about the suported hardware.
4. Open the **Custom Devices** page in Vespera.
5. Click the "Scan" button; After a few seconds, available device(s) will appear in the "Discovered Devices" page.
6. Click to select the device to bind to.
7. Select the service to bind to the device.
8. Finally click the "Add Device" button and the device should then bind to the service.
9. Depending on the device, it should now appear and be running in the Venus OS.

![Custom devices](images/discovered-device.webp "Custom devices screenshot")
Basic usage:

10. Use the Vespera>Discovered Devices to view existing bound devices, and remove the binding.

---
#### Previous - [Setup](setup.md)