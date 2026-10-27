# Network GPS Setup - GL.iNet GL-X3000

This guide is specific to the GL.iNet GL-X3000 (Spitz AX).

Manufacturer page:
[GL.iNet GL-X3000 Product Page](https://www.gl-inet.com/products/gl-x3000/)

## Prerequisites

* GL.iNet GL-X3000 router.
* Venus OS device (for example, Cerbo GX) on the same reachable network.
* SSH access to the router.

## 1) Router GPS Setup

1. Log in to the GL-X3000 web UI.
2. Enable `gpsd` in the modem/5G settings.
3. In cellular settings, send the AT commands shown in the upstream guide:

```bash
AT+QGPSCFG="autogps",1
AT+QGPS=1
```

4. SSH into the router and install the full `socat` package:

```bash
opkg update
opkg install socat
```

5. Verify GPS output is active:

```bash
cat /dev/mhi_LOOPBACK
```

The command should stream NMEA messages (for example `$GPGGA`, `$GPRMC`, `$GPGSV`).
```
$GPGSV,3,2,10,25,24,103,38,26,54,316,43,27,12,249,26,28,59,203,25,1*67
$GPGSV,3,3,10,29,40,045,28,31,65,260,31,1*66
$GPGSV,1,1,0,8*5D
$GPGGA,143653.00,3649.353448,N,00442.549153,W,1,08,0.4,194.6,M,47.8,M,,*7D
$PQXFI,143653.0,3649.353448,N,00442.549153,W,194.6,3.54,2.50,0.09*75
$GPVTG,,T,359.8,M,0.0,N,0.0,K,A*0A
$GPRMC,143653.00,A,3649.353448,N,00442.549153,W,0.0,,020225,0.2,E,A,V*78
$GPGSA,A,3,16,18,25,26,27,28,29,31,,,,,0.7,0.4,0.5,1*22
```

## 2) Install Forwarding Service on Router

1. Download and run the installer:

```bash
wget -O gpsdservice-install.sh https://raw.githubusercontent.com/nj-andrews/GLX3000-GPS/refs/heads/main/gpsdservice-install.sh
chmod 755 gpsdservice-install.sh
./gpsdservice-install.sh
```

2. Enter the Venus OS IP address when prompted.
3. Confirm service status:

```bash
service --status-all | grep 'gpsdservice'
```

Optional management commands:

```bash
/etc/init.d/gpsdservice stop
/etc/init.d/gpsdservice disable
```

Update the configured Venus OS IP later if needed:

```bash
uci set gpsdservice.venus.ip=<ip-address>
uci commit gpsdservice
```

## 3) Validate on Venus OS

1. Confirm Venus OS starts receiving NMEA0183 data.
2. Wait a few minutes for GPS location data to appear.
3. Verify position updates in VRM portal tracking views.

---
#### Previous - [Network GPS Setup](network-gps-setup.md)