# Solar Divert Overview

This add-on is planned and currently under development.

The Solar Divert add-on is intended to manage a relay based on excess solar availability. In a typical installation, a Cerbo GX relay can be switched on when the battery is fully charged and the system is not on shore power, and switched off again when the battery level drops below a configured threshold.

This is useful for appliances that support a solar signal input, such as some fridges or accessories that can switch between grid/mains power and battery power based on a control signal.

## Prerequisite

Install [Vespera](../vespera/setup.md) before using this add-on.

## Intended behavior

- Monitor battery charge state and power conditions.
- Use a Cerbo GX relay output as a solar-available signal.
- Turn the relay on during excess solar availability.
- Turn the relay off again when the battery falls below the configured threshold.

## Notes

- This add-on is not yet production-ready in this workspace.
- Setup documentation will be added once the feature is complete.

---
#### Previous - [Add-ons Index](../addons-overview.md)