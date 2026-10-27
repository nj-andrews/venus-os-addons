# Installer Integration Patterns (Developer Note)

This note explains why Vespera avoids editing shared system or GUI files directly during package install and remove.

For the small number of file-level seams that still need integration, Vespera uses the package-owned patch utilities in `src/data/apps/available/vespera/libs/file-patcher-lib`. The install and remove lifecycle code in `scripts/install` and `scripts/remove` invokes those helpers instead of relying on fragile one-off edits to upstream files.

## Why this matters

Installers run on many firmware versions and combinations of add-ons. Shared-file patching is fragile in that environment because each package does not fully control the final file state.

## Patch workflow vs structured integration

| Topic | Patch-based workflow | Structured integration pattern |
| --- | --- | --- |
| Firmware drift | A patch can fail when upstream files change. | Integration reads or writes package-owned state that remains stable across versions. |
| Multi-package behavior | Multiple packages editing the same file can conflict by install order. | Each package owns its own entries or generated fragments, reducing coupling. |
| Uninstall and rollback | Exact restoration is hard when multiple patches overlap. | The package removes only the artifacts it owns. |
| Observability | Failures often appear as partial hunks or silent offsets. | Behavior is explicit in helper scripts, config files, and package metadata. |
| Upgrade safety | Reapplying old patch hunks after firmware updates is risky. | The install logic can reconcile state from current metadata rather than mutating stale base files. |

## Preferred patterns in Vespera

- Prefer package-owned files, generated fragments, and registries over editing shared base files directly.
- When a QML or system file must be touched, keep the change small and isolated to a clearly owned integration seam.
- Use the file patch helpers so the apply and revert steps remain symmetric and repeatable.
- Model integration through settings, manifests, and helper scripts that can be re-applied safely.
- Keep ownership clear: install creates package-owned artifacts, uninstall removes only the artifacts it created.
- Design for idempotency: repeated install/remove actions should converge to the same stable state.

## Overlay paths (`<app>.installer-overlays`)

Vespera's own `vespera.installer-overlays` lists the **master** paths (for example `/opt/victronenergy`). They are always used, even when vespera is disabled.

How an app's overlay paths are resolved (paths are compared by whole path component, so `/opt/victronenergy2` is unrelated to `/opt/victronenergy`):

- A path inside a master (`/opt/victronenergy/qml`) is mounted as the master (`/opt/victronenergy`).
- A path inside a path already installed by another app resolves to that path. Disabled apps count; every installed app does.
- A path that contains a master (`/opt`, `/etc`), `/`, a relative path, or a path with `..` is rejected.
- A path that contains a path installed by another app (`/aaa/bbb` after `/aaa/bbb/ccc`) is rejected, because mounting it would hide the other app's overlay. The error names the owning app.
- Resolution is all-or-nothing and happens in `preinst`; a rejected app is not installed.
- The resolved target is pinned in `installed.conf` at install time and is not recomputed. If the app that owned `/aaa` is uninstalled, an app that resolved to `/aaa` keeps using it until it is uninstalled.

Side effects to be aware of:

- Apps that resolve to the same target share one overlay mount and one upper directory, so files written by one app are visible to the others.
- Install order matters for non-master paths: the first app decides the target that later apps fold into, and a later parent path cannot be installed.
- Installs made before `installed.conf` existed have no pinned entries; reinstall such apps to pin them.


