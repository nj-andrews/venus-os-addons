# Mount Shares Overview

The Mount Shares add-on is most useful when you are connected to Venus OS over SSH.
It allows you to mount SMB/CIFS and NFS network shares using a helper script.

## Prerequisite

Install [Vespera](../vespera/setup.md) first before using this add-on.

## Main Script

The main script is:

```bash
/data/apps/mount-shares/mount-lib
```

You can use it to:

* Mount a share and save its settings.
* Mount all previously saved shares.
* Remove saved entries (via the usage workflow).

## Configuration File

Mount Shares stores saved mount definitions in:

```bash
/data/apps/conf/mount-shares.conf
```

Purpose of this file:

* Keeps one saved mount entry per target mount path.
* Lets the system restore mounts later without re-entering all mount arguments.

## Automatic Re-mount After Reboot

Shares mounted through `mount-lib` are automatically re-mounted after reboot.
At startup, Mount Shares runs:

```bash
/data/apps/mount-shares/mount-lib mount-all
```

This command reads `/data/conf/mount-shares.conf` and mounts each saved share.

---
#### Next - [Usage](usage.md)