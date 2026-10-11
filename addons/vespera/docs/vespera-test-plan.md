# Vespera Test Plan

## Overview
This plan focuses on the currently shipped Vespera addon structure and the code paths that are exercised by the active shell tests under `tests/`.

The current implementation is organized around:
- `src/data/apps/available/vespera/libs/` for install/remove logic
- `src/data/apps/available/vespera/scripts/` for entrypoints
- `src/data/apps/available/vespera/services/` for service runtime behavior
- `src/opt/victronenergy/gui/qml/` for the Venus GUI layer

---

## Phase 1: Vespera CLI full functionality

The Vespera CLI is the primary automation and troubleshooting entrypoint, so it is tested first.

### 1.1 Help and argument parsing
- [x] Verify `vespera --help` prints the current command summary and usage text.
- [x] Verify `vespera help` combines vespera help and opkg help.
- [x] Verify `-V0` through `-V4` arguments are accepted without breaking opkg invocation.
- [x] Verify `--in-gui` is handled without side effects in the normal shell path.

### 1.2 Status and package listing
- [x] Verify `vespera status` prints package state using the active combined opkg config.
- [x] Verify `vespera list-enabled` returns the expected enabled apps or packages.
- [x] Verify `vespera inspect` reports app, service, addon, and DBus details without errors.

### 1.3 Feed and update operations
- [x] Verify `vespera feeds-conf, '', `list`, `set`, `remove` confirm api works.
- [x] Verify `vespera feeds-source` `add`, `edit`, `remove` confirm api works.
- [x] Verify `vespera update` refreshes package metadata and regenerates indexes cleanly.

### 1.4 Device operations
- [x] Verify `vespera device scan` resolves USB serial devices and returns the expected state.
- [x] Verify `vespera device bind <tty>` updates the service mapping without creating duplicates.
- [x] Verify `vespera device remove <tty>` removes stale device bindings and config entries cleanly.
- [x] Verify invalid or missing tty/device arguments fail with a clear error rather than corrupting system state.

### 1.5 Enable/disable and runtime state
- [x] Verify `vespera enable` enables matching installed apps and leaves the system in a stable state.
- [x] Verify `vespera disable` disables the selected apps without leaving stale service or overlay state.

### 1.6 opkg passthrough behavior
- [x] Verify unknown commands are passed through to `opkg` using the active combined config.
- [x] Verify `vespera install <pkg>`, `vespera remove <pkg>`, and `vespera upgrade <pkg>` execute as expected via opkg passthrough.
- [x] Verify opkg passthrough preserves exit codes for success and failure cases.
- [ ] Verify opkg passthrough output remains visible for troubleshooting (stdout/stderr not swallowed).

---

## Phase 2: GUI-v2 Vespera integration in Venus GUI

### 2.1 Navigation and page loading
- [x] Open the Vespera entrypoint in Venus GUI and verify all GUI-v2 Vespera pages load.
- [x] Verify navigation to package, feed, and device pages works without rendering errors.
- [x] Verify return/back navigation preserves expected state and does not crash the page stack.

### 2.2 Bridge and operation wiring
- [x] Trigger package list refresh from GUI-v2 and verify data is returned and rendered.
- [ ] Trigger feed operations from GUI-v2 and verify status, completion, and error messages are shown.
- [x] Trigger device scan/bind/remove from GUI-v2 and verify UI state updates match backend results.
- [x] Trigger Install/Upgrade/Remove works and signals the Gui will restart.
- [x] Indidator is blue for installed apps, orange for installed apps when upgrade is available.
- [x] Trigger Enable Disable of package. Packages indicator dims.


### 2.3 Runtime behavior and resilience
- [x] Verify GUI-v2 reflects long-running CLI operations with clear progress or busy state.
- [ ] Verify GUI-v2 recovers cleanly after an operation failure or canceled action.
- [x] Verify no stale data remains after returning to the page after a completed operation.

---

## Phase 3: GUI-v1 Vespera integration in Venus GUI

### 3.1 Legacy page behavior
- [ ] Verify GUI-v1 Vespera menu entry is visible where expected on the target firmware.
- [ ] Verify GUI-v1 pages open and render package/feed/device information correctly.
- [ ] Verify legacy navigation and back stack behavior is stable.

### 3.2 Feature parity checks against CLI
- [ ] Compare GUI-v1 package operations against equivalent CLI commands for expected outcomes.
- [ ] Compare GUI-v1 feed operations against equivalent CLI commands for expected outcomes.
- [ ] Compare GUI-v1 device actions against equivalent CLI commands for expected outcomes.

### 3.3 Error handling
- [ ] Verify GUI-v1 reports operation failures in a user-visible and actionable way.
- [ ] Verify GUI-v1 does not enter broken state after failed operations.

---

## Phase 4: Blind-install testing

### 4.1 Package creation and media staging
- [ ] Build the blind-install artifact using the bootstrapper workflow.
- [ ] Verify the generated archive and expected payload files are present.
- [ ] Verify copy-to-drive workflow places files in the expected destination layout.

### 4.2 First-boot execution path
- [ ] Verify blind-install startup hook runs on target boot.
- [ ] Verify install logs indicate package extraction and install steps completed.
- [ ] Verify failure paths write actionable logs when media or payload is invalid.

### 4.3 Post-install validation
- [ ] Verify Vespera package is installed and services are enabled after blind-install.
- [ ] Verify GUI integration entrypoint is available after boot.
- [ ] Verify rerunning the blind-install path is idempotent and does not duplicate state.

---

## Phase 5: Core package lifecycle checks

### 5.1 Fresh install
- [x] Install or refresh the Vespera package with the project package workflow.
- [x] Verify the package files land under `/data/apps/available/vespera/` in the target machine.
- [x] Verify all Vespera GUI pages are present in the Venus GUI asset tree.
- [x] Verify basic functionality works, refresh packages.

### 5.2 Runtime enablement
- [x] Confirm Vespera services start cleanly after install.
- [x] Verify the main Vespera pages are visible and selectable.

---

## Phase 6: Feed and package metadata checks

### 6.1 Feed config
- [ ] Verify the combined opkg configuration is valid.
- [ ] Confirm feed entries are available in the generated package index metadata.
- [ ] Check that feed metadata still loads when the cache is empty or stale.

### 6.2 Feed refresh
- [x] Trigger a feed refresh through the Vespera CLI or package logic.
- [x] Verify the update path completes without an invalid index state.
- [x] Confirm the cached package list is refreshed and parseable.

---

## Phase 7: Package operations

### 7.1 Install
- [ ] Run the install flow through the package lifecycle entrypoint.
- [ ] Verify the application is added to the enabled/installed state list.
- [ ] Confirm the app-level runtime logic is invoked and completes without partial state.

### 7.2 Remove
- [ ] Run the remove flow through the package lifecycle entrypoint.
- [ ] Verify installed state is cleaned up.
- [ ] Confirm remove logic does not leave stale symlinks or generated metadata behind.

### 7.3 Upgrade/reinstall safety
- [x] Run an upgrade-install path and verify state transitions are preserved.
- [ ] Verify remove/upgrade flows do not duplicate entries in package or device state files.

---

## Phase 8: Serial device installer coverage

### 8.1 Device detection
- [ ] Verify `sdi_get_available_devices` handles normal USB tty devices and ignores stale or invalid entries.
- [ ] Verify udev property parsing returns the expected USB fields for a discovered device.
- [ ] Confirm device SID generation is deterministic for equivalent USB metadata.

### 8.2 Device binding
- [ ] Verify a tty resolves to the correct service name and service mapping.
- [ ] Verify duplicate device rules are not written twice.
- [ ] Verify a damaged or missing symlink is repaired by the installer logic.

### 8.3 Remove and cleanup
- [ ] Remove a bound device rule and verify the serial-starter rule is cleaned up.
- [ ] Verify the service mapping is removed from the config when the device is unbound.
- [ ] Confirm stale locks or leftover tty state are not kept around after cleanup.

---

## Phase 9: DBus and settings integration

### 9.1 DBus state
- [ ] Confirm settings values are written under the expected DBus subtree.
- [ ] Verify remove flows do not leave stale DBus entries behind.
- [ ] Check that device settings can be created and reconciled across repeated scan/bind cycles.

### 9.2 Settings persistence
- [ ] Verify values survive a typical package lifecycle transition.
- [ ] Confirm the package does not create duplicate config entries after re-install.

---

## Phase 10: Operational checks

### 10.1 Startup and service restart
- [ ] Verify Vespera startup scripts remain idempotent.
- [ ] Ensure service restarts do not leave stale services behind.
- [ ] Check that all expected services respond to enabled/disabled transitions.

### 10.2 Failure handling
- [ ] Validate error behavior when device properties are missing or malformed.
- [ ] Validate invalid install state or conflicting service names fail cleanly.
- [ ] Confirm stale file or symlink conditions are handled without corrupting config state.

---

## Phase 11: Regression focus

The regression suite should stay centered on the most failure-prone paths:

- repeated install/remove cycles
- duplicate service mapping entries
- stale tty and lock cleanup
- udev property parsing edge cases
- config file repair and symlink correction
- Vespera CLI argument parsing and exit code behavior

---

## Phase 12: Evidence collection

### Required logs and files
- [ ] test output from the active shell tests under `tests/`
- [ ] package lifecycle logs generated during a real install/remove cycle
- [ ] CLI output from key `vespera` commands (`status`, `list-enabled`, `device`, `update`, `feed`) and passthrough commands (`install`, `remove`, `upgrade`)
- [ ] GUI-v2 test evidence (screenshots/logs) for package/feed/device operations
- [ ] GUI-v1 test evidence (screenshots/logs) for package/feed/device operations
- [ ] blind-install logs and produced artifact checksums or file lists
- [ ] any relevant serial-starter or device binding logs from the target system
- [ ] known-good device metadata samples used in the test fixtures

### Validation gate
- [ ] The active Vespera test suite runs cleanly before release.
- [ ] A targeted serial-device regression run passes after any lifecycle change.
- [ ] The main `vespera` CLI commands and opkg passthrough paths succeed with stable exit codes and expected output.
- [ ] GUI-v2 and GUI-v1 integration checks pass for the targeted firmware variants.
- [ ] Blind-install path completes and remains repeatable.

---

## Sign-Off

| Phase | Status | Date | Notes |
|-------|--------|------|-------|
| 1. Vespera CLI | ☐ | | |
| 2. GUI-v2 integration | ☐ | | |
| 3. GUI-v1 integration | ☐ | | |
| 4. Blind-install | ☐ | | |
| 5. Core lifecycle | ☐ | | |
| 6. Feed metadata | ☐ | | |
| 7. Package operations | ☐ | | |
| 8. Serial devices | ☐ | | |
| 9. DBus/settings | ☐ | | |
| 10. Operational checks | ☐ | | |
| 11. Regression focus | ☐ | | |
| **Overall Status** | ☐ | | |
