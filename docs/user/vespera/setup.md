# Vespera Setup

### Blind Install Using Removable USB Media
To install via usb drive or sd card
* Format the device as FAT (not FAT32 or exFAT)
* Download the file below to the sd card:
  [venus-data-vespera-blind-install.tgz](https://nj-andrews.github.io/venus-os-addons/feeds/release/vespera/venus-data-vespera-blind-install.tgz)

* Insert the usb device into the Cerbo GX or Raspberry Pi and reboot.

### SSH
To install via SSH execute the following command
```Shell
wget -qO vespera-bootstrap https://nj-andrews.github.io/venus-os-addons/feeds/vespera-bootstrap && sh ./vespera-bootstrap
```

# Advanced blind config options
The blind-install archive can optionally use two venus-data-vespera-blind-install.conf/.sh files, which should reside next to the venus-data-vespera-blind-install.tgz file on the sd card.
`venus-data-vespera-blind-install.conf`
`venus-data-vespera-blind-install.sh`

### venus-data-vespera-blind-install.conf
This file should optionaly contain
```
bootstrap-url=http://192.168.10.32:8808
bootstrap-release=develop
min-version=2.0
```

#### bootstrap-url
The url location of the vespera-bootstrap file use to download and setup vespera
`http://192.168.12.42:8808/vespera-bootstrap`

if not supplied the default url of:
`https://nj-andrews.github.io/venus-os-addons/feeds` is used

#### bootstrap-release
A string identifying the type/location of the vespera_latest.ipk package
examples; develop|release|test
This string gets appended to the bootstrap-url to create:
`http://192.168.12.42:8808/develop/vespera-latest.ipk`

### venus-data-vespera-blind-install\.sh
A script file called after vespera is installed.
Use this script to setup vespera to your requirements.
- change/add/ remove feeds
- install other packaged
- setup usb devices
- etc.

### Log file
The log file for a bind-install is located in /var/log/vespera/blind-install.log. The log file is re-created on every blind-install

### Installed
Once installed, To find vespera in the Venus OS goto:

New Gui (gui-v2); goto Settings/Intergrations
Classic Gui; goto Menu/Settings

![Vespera menu screenshot](images/vespera-intergration.webp "Vespera Menu")


---
#### Previous - [Overview](overview.md)
#### Next - [Usage](usage.md)