# Set up the Venus Os for Debugging Python/C++ using Visual Studio Code

## Setup

Use a RaspberryPi 4B
Install Venus OS on sd card 

Set wifi in Venus OS
Use Victron Connect App. Select Rasperry pi, enter bluetooth pin, then connect to wifi
Note if Wifi fails, connect ethernet cable instead and connect wifi using Venus OS GUI

In Venus GUI to enable ssh, select settings/general/accesslevel then press and hold right arrow key for 5 seconds (or drag down with mouse in browser) to enable root access
add ssh password

SSH into Venus OS
Set up ssh key (using Terminus)
Vaults>>Key chain> select id with rp4 and export
or in windows
copy text in file user/.ssh/keys/id_xxx.pub into the file ~/root/.ssh/authorized_keys file changing name to root@raspberypi (although name does not appear matter)

https://www.victronenergy.com/live/ccgx:root_access

### set up dev environment

Download and run dev_setup from github

Adds a opkg feed for installing custom packages from this repository

```
wget https://raw.githubusercontent.com/nj-andrews/venus-os-addons/refs/heads/main/tasks/dev-setup -O /data/dev-setup
chmod +x /data/dev-setup
/data/dev-setup
```

#### Installs
     Packages to replace BusyBox (so we can remote debug using VS Code)  
     Python 3 (full version)  
     libatomic1 (required by Python 3)  

#### Install custom packages
     vespera: A package for installing custom opkg packages on the Venus OS which will automatically get re-installed after firmware updates  
     mount-shares: A package for mounting nfs and cfs shares  


## Install vespera only
```
wget https://raw.githubusercontent.com/nj-andrews/venus-os-addons/refs/heads/main/tasks/install-vespera -O /tmp/install-vespera
chmod +x /tmp/install-vespera
/tmp/install-vespera

```

In Visual Studio use remote debugging 
root@192.xxx.xxx.xxx  
open remote folder in /data/dev/projects  
may need to remove .env folder from project  
debug code...  









