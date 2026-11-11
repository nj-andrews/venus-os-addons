# Release Notes

## Release-2026.11.9

### dbus-inetbox/v0.1.4
- Fix LIN message parsing that could produce incorrect error codes.
- Improve Truma error descriptions and display multiple causes on separate lines.

### dbus-ne-shunt/v0.1.2
- Fix initial values not being loaded from settings.
- Add the `DeviceKey` setting to enable inspection in Vespera.

## Release-2026.11.8

### dbus-ne-shunt/v0.1.1
- Avoid restarting unnecessary Venus services during installation or removal.

### vespera/v0.1.11
- Fix device refresh after disabling apps that use templated services.

## Release-2026.11.7

### dbus-inetbox/v0.1.3
- Add the `DeviceKey` setting for Inetbox to enable inspecting.

### vespera/v0.1.10
- Fix app service restarts after upgrades.
- Refresh device mappings after service installs/removals and improve templated-service startup handling.
