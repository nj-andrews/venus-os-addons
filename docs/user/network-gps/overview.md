# Network GPS Overview

The Network GPS add-on enables forwarding NMEA GPS messages from a compatible network source without requiring a dedicated GPS dongle.

## Prerequisite

Install [Vespera](../vespera/setup.md) first before using this add-on.

Venus OS automatically recognizes standard NMEA0183 messages after startup and initial data flow.

### VRM Portal Tracking
Once the GPS has a lock, your unit location is sent to the Victron Remote Management (VRM) portal.

* Live tracking: your location is plotted directly on the map.
* Geofencing: you can configure a geofence in VRM to receive alerts if your system leaves a designated area.
* Historical data: you can download GPS tracks as `.kml` files for tools such as Google Earth.

---
#### Next - [Setup](setup.md)