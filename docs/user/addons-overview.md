# Add-ons documentation overview

This page lists the add-ons currently documented in this workspace and links to the most relevant user guide pages.

## Core system tools

| Add-on | Purpose | Links |
|--------|---------|-------|
| [Vespera](vespera/overview.md) | Installs and manages additional Venus OS packages and feeds. | [Overview](vespera/overview.md) · [Setup](vespera/setup.md) · [Usage](vespera/usage.md) |

## User-facing integrations

| Add-on | Purpose | Links |
|--------|---------|-------|
| [Inetbox](inetbox/overview.md) | Controls Truma heating and air-conditioning via compatible Inetbox hardware. | [Overview](inetbox/overview.md) · [Hardware](inetbox/hardware.md) · [Setup](inetbox/setup.md) · [Usage](inetbox/usage.md) |
| [Ne Shunt](ne-shunt/overview.md) | Integrates supported Nordelec / Nordelettronica shunt devices into Venus OS. | [Overview](ne-shunt/overview.md) · [Hardware](ne-shunt/hardware.md) · [Setup](ne-shunt/setup.md) · [Usage](ne-shunt/usage.md) |
| [Network GPS](network-gps/overview.md) | Sends GPS tracking data from a network source to Venus OS. | [Overview](network-gps/overview.md) · [Setup](network-gps/setup.md) |
| [Mount Shares](mount-shares/overview.md) | Mounts SMB/CIFS and NFS shares on the system and restores them after boot. | [Overview](mount-shares/overview.md) · [Usage](mount-shares/usage.md) |
| [Themer](themer/overview.md) | Adds UI theme support and previews for the dashboard. | [Overview](themer/overview.md) |
| [Solar Divert](solar-divert/overview.md) | Planned relay add-on driven by excess solar availability. | [Overview](solar-divert/overview.md) |

## Recommended reading order

1. [Vespera overview](vespera/overview.md)
2. [Inetbox overview](inetbox/overview.md)
3. [Ne Shunt overview](ne-shunt/overview.md)
4. [Network GPS overview](network-gps/overview.md)
5. [Mount Shares overview](mount-shares/overview.md)
6. [Themer overview](themer/overview.md)

## Notes

- Some add-ons depend on specific hardware and are only useful with compatible devices.
- The repository uses release feeds for stable installs, while development feeds are meant for testing.
- For production systems, prefer the release feed and follow the setup steps in the matching add-on guide.

---

#### Previous - [Main documentation](../../readme.md)
