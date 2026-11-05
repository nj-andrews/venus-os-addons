# vespera DBus Process Service


## DBus Service

- Service: com.victronenergy.vespera
- Interface for item access: com.victronenergy.BusItem

## Writable Request Paths

- /Request/ArgsJson - JSON array: `["<family>", "<action>", ...args]`
- /Request/Start - increment to run `scripts/gui-executor` with ArgsJson (ignored while a command is running)

## Command Progress

The service publishes nothing about a running command. `scripts/gui-executor` writes progress to
com.victronenergy.settings, which the GUI watches:

- /Settings/Vespera/Gui/Command - `<family> <action>`
- /Settings/Vespera/Gui/Output - latest output line
- /Settings/Vespera/Gui/ExitCode - `-1` while running, then the exit code

