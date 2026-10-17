# Vespera locale loader cross-build notes

This project builds a Qt QML plugin for the Venus OS ARM target. The working setup is the Venus SDK already installed on this machine, not the generic Ubuntu cross-toolchain packages.

## What is required

The project must be built against the Venus OS ARM sysroot and the matching ARM compiler from the Venus SDK:

- sysroot: `/opt/venus/scarthgap-arm-cortexa8hf-neon/sysroots/cortexa8hf-neon-ve-linux-gnueabi`
- compiler prefix: `arm-ve-linux-gnueabi-`
- Qt6 package path: `/opt/venus/scarthgap-arm-cortexa8hf-neon/sysroots/cortexa8hf-neon-ve-linux-gnueabi/usr`

This is a hard-float ARM target, so the compiler must be invoked with:

- `-mfpu=neon`
- `-mfloat-abi=hard`
- `-mcpu=cortex-a8`
- `--sysroot=/opt/venus/scarthgap-arm-cortexa8hf-neon/sysroots/cortexa8hf-neon-ve-linux-gnueabi`

## Working setup

Use the shipped Venus environment script:

```bash
set -a
. /opt/venus/scarthgap-arm-cortexa8hf-neon/environment-setup-cortexa8hf-neon-ve-linux-gnueabi
set +a
```

This exports the correct `CC`, `CXX`, `SDKTARGETSYSROOT`, and target flags.

## Verify the toolchain is present

```bash
ls /opt/venus/scarthgap-arm-cortexa8hf-neon/sysroots/x86_64-ve-linux/usr/bin/arm-ve-linux-gnueabi
ls /opt/venus/scarthgap-arm-cortexa8hf-neon/sysroots/cortexa8hf-neon-ve-linux-gnueabi/usr/lib/cmake/Qt6/Qt6Config.cmake
```

You should see the ARM cross compiler binaries and Qt6 config files.

## Build the plugin

From the repo root:

```bash
cd /data/dev/addons/vespera
./src-external/vespera-locale-loader/build.sh armhf
```

The script in [build.sh](build.sh) now:

- detects the Venus SDK automatically
- uses the `arm-ve-linux-gnueabi-*` compiler family
- injects the hard-float sysroot flags
- points `CMAKE_PREFIX_PATH` at the target Qt6 installation
- fails if the required ARM environment is not present

## Why the Ubuntu package names were not enough

The generic Ubuntu packages (`arm-linux-gnueabihf-*`) do not match the actual Venus OS toolchain layout. The real target here is the Venus SDK with the `arm-ve-linux-gnueabi` toolchain and the `cortexa8hf-neon-ve-linux-gnueabi` sysroot.

Using the wrong toolchain name or missing sysroot results in linker errors like:

- `cannot find crt1.o`
- `cannot find -lstdc++`
- `cannot find crtbegin.o`

These happen because the compiler is not being given the correct target sysroot.

## Final output

The build places the plugin and compiled translation file under:

- `/data/dev/addons/vespera/src/opt/victronenergy/gui/qml/Vespera/libvesperalocale.so`
- `/data/dev/addons/vespera/src/opt/victronenergy/gui/qml/Vespera/lang/Vespera_en.qm`

This matches the GUI v1 overlay layout used by the addon.
