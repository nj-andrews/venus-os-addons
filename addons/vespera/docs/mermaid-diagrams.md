# Vespera Mermaid diagrams

This document captures the current code-level flows for the Vespera addon.

Related: [Installer Integration Patterns (Developer Note)](installer-integration-patterns.md)

## 1) High-level architecture

```mermaid
flowchart LR
    UI[QML pages\nVesperaHomePage / VesperaPageSettings*.qml] --> MANAGER[VesperaManager]
    MANAGER --> BRIDGE[VesperaBridge]

    BRIDGE --> CLI[vespera CLI / helper scripts]
    CLI --> LIBS[libs/installer-lib\nlibs/opkg-lib\nlibs/device-lib\nlibs/serial-device-installer-lib]
    CLI --> DATA[/data/apps/available/vespera/]

    LIBS --> CONF[conf/vespera.conf\nconf-default/vespera.conf]
    LIBS --> STATE[/tmp/vespera/\nstatus and indexes]
    UI --> JSON[VesperaJsonReader / JSON cache]
    JSON --> STATE
```

## 2) Package install / upgrade / remove flow

```mermaid
sequenceDiagram
    participant User
    participant UI as VesperaPageSettingsPackages.qml
    participant Manager as VesperaManager
    participant Bridge as VesperaBridge
    participant CLI as vespera CLI / scripts
    participant Lib as installer-lib / vespera-lib
    participant FS as package files + overlays

    User->>UI: open packages page
    UI->>Manager: load package list / install action
    Manager->>Bridge: request operation
    Bridge->>CLI: launch helper script
    CLI->>Lib: initialize install/upgrade/remove flow
    Lib->>FS: update package state, manifests, overlays
    CLI-->>Bridge: exit code + streamed output
    Bridge-->>Manager: finished(result)
    Manager-->>UI: refresh package model
```

## 3) Feed management flow

```mermaid
sequenceDiagram
    participant User
    participant FeedPage as VesperaPageSettingsFeeds.qml
    participant Manager as VesperaManager
    participant Bridge as VesperaBridge
    participant Lib as opkg-lib / feed logic
    participant Cache as /tmp/vespera/feeds.json

    User->>FeedPage: open feed settings
    FeedPage->>Manager: list feeds / add / remove / edit
    Manager->>Bridge: request feed operation
    Bridge->>Lib: run opkg feed update logic
    Lib-->>Cache: write updated feed metadata
    Bridge-->>Manager: finished(exitCode)
    Manager-->>FeedPage: refresh model
```

## 4) Device binding lifecycle

```mermaid
sequenceDiagram
    participant Device as USB serial device
    participant Udev as udev + serial-device-installer-lib
    participant DeviceLib as device-lib
    participant Service as service-lib / runit service
    participant DBus as dbus-lib

    Device->>Udev: trigger add event
    Udev->>DeviceLib: resolve tty / usb props / SID
    DeviceLib->>DBus: bind device metadata
    DeviceLib->>Service: ensure service mapping and start service
    Service-->>Device: service active for tty
```

## 5) Responsibility map

```mermaid
flowchart TB
    subgraph Package[package lifecycle]
        Install[scripts/install + scripts/remove]
        Installer[installer-lib]
        VesperaLib[vespera-lib]
    end

    subgraph Device[serial device handling]
        DeviceLib[device-lib]
        SDI[serial-device-installer-lib]
        ServiceLib[service-lib]
    end

    subgraph GUI[Venus GUI layer]
        Manager[VesperaManager]
        Bridge[VesperaBridge]
        Pages[VesperaPageSettings*.qml]
    end

    GUI --> Bridge
    Bridge --> Install
    Install --> Installer
    Installer --> VesperaLib
    DeviceLib --> SDI
    SDI --> ServiceLib
    VesperaLib --> DeviceLib
```

The current design separates:
- GUI concerns in the QML layer
- package lifecycle in the installer and helper scripts
- serial device binding in `device-lib` and `serial-device-installer-lib`
- runtime restarts and state cleanup in `vespera-lib` and `service-lib`

## 6) Device setup state flow

```mermaid
stateDiagram-v2
    [*] --> idle
    idle --> discover: scan for tty / USB props
    discover --> bind: resolve SID and service mapping
    bind --> ready: install rules + register device
    ready --> service_running: start service for tty
    service_running --> idle: device removed or rebound
    bind --> error: invalid tty / missing props
    error --> idle: cleanup and reset
```

## Source anchors

- [src/opt/victronenergy/gui/qml/VesperaManager.qml](../src/opt/victronenergy/gui/qml/VesperaManager.qml)
- [src/opt/victronenergy/gui/qml/VesperaBridge.qml](../src/opt/victronenergy/gui/qml/VesperaBridge.qml)
- [src/opt/victronenergy/gui/qml/VesperaPageSettingsPackages.qml](../src/opt/victronenergy/gui/qml/VesperaPageSettingsPackages.qml)
- [src/opt/victronenergy/gui/qml/VesperaPageSettingsFeeds.qml](../src/opt/victronenergy/gui/qml/VesperaPageSettingsFeeds.qml)
- [src/data/apps/available/vespera/vespera](../src/data/apps/available/vespera/vespera)
- [src/data/apps/available/vespera/libs/device-lib](../src/data/apps/available/vespera/libs/device-lib)
- [src/data/apps/available/vespera/libs/serial-device-installer-lib](../src/data/apps/available/vespera/libs/serial-device-installer-lib)