# Build

## Host requirements

- Windows 10/11 + WSL2 (tested with Ubuntu 26.04), or Linux.
- 8 GB RAM minimum; 16 GB comfortable. ~8 GB disk for the hardware base and rootfs.
- Python 3.10+ on the host that runs `duo`; the build runs in WSL/Linux.

`duo setup --native` installs:

```
build-essential gcc-aarch64-linux-gnu flex bison bc libssl-dev libelf-dev
libncurses-dev rsync cpio kmod device-tree-compiler python3 git ca-certificates
zstd xz-utils dosfstools mtools e2fsprogs parted fdisk mmdebstrap
qemu-user qemu-user-binfmt binfmt-support debian-archive-keyring squashfs-tools
```

`duo setup --rootless` downloads a static `proot` and an Ubuntu base rootfs into
`~/.cache/duolinux` and installs the same tools there. Slower, no sudo.

## Stages

### 1. `duo fetch` (Lite)

- Downloads `ROCKNIX-SM6115.aarch64-20261029.tar` (~1.4 GB) from the ROCKNIX nightly release.
- Extracts `target/KERNEL` (raw arm64 Image), `target/SYSTEM` (squashfs), the Duo Lite DTB, the
  SM6115 ABL and its scripts.
- Extracts modules, firmware and UCM from `SYSTEM` with `unsquashfs`:
  - `usr/lib/kernel-overlays/base/lib/modules/7.2.0/` (274 `.ko`)
  - `usr/lib/kernel-overlays/base/lib/firmware/` (WCN3990, WCN3950, ADSP, A610, Venus)
  - `usr/share/alsa/ucm2/`
- Downloads the newest arm64 Tailscale `.deb`.

### 2. `duo kernel` (Lite)

No compilation. Copies the ROCKNIX `Image`, DTB and modules into `out/kernel/`. This is the board
support package; the kernel is GPL-2.0 and its source/patchset is documented below.

### 3. `duo rootfs`

- `mmdebstrap` builds Debian 13 arm64 `minbase` with `configs/rootfs/packages.list`.
- Copies `overlay/`, ROCKNIX firmware/UCM, kernel modules, and Tailscale's `.deb`.
- Runs `configs/rootfs/setup.sh` in the chroot: user, groups, fstab, hostname, services, SSH,
  sudoers.

Rootfs build needs root because it runs `chroot` and maintainer scripts. Kernel/image assembly does
not.

### 4. `duo image`

- `initramfs.py` builds a busybox cpio with `/duo-init`, which finds `LABEL=STORAGE`, mounts it, and
  `switch_root`s.
- `build.py` packs `boot.img` (Android header v2: kernel + ramdisk + DTB + cmdline) and the boot
  directory (`KERNEL`, `initrd.img`, DTB, `extlinux.conf`, BLS entry).
- `image.py` writes GPT, FAT32 `ROCKNIX`, ext4 `STORAGE`, and copies both partitions in.
- Output: `out/duolinux-duol.img`, `out/SHA256SUMS`.

## Kernel provenance and source build

The prebuilt path uses:

- Kernel: ROCKNIX SM6115 nightly `20261029`, kernel **7.2.0**
- Config: `projects/ROCKNIX/devices/SM6115/linux/linux.aarch64.conf`
- DTS: `projects/ROCKNIX/devices/SM6115/linux/dts/qcom/sm6125-retroid-pocket-duo-lite.dts`
- Patches: `projects/ROCKNIX/devices/SM6115/patches/linux/*.patch` (panels, WL818S bridge, Himax
  touch, WCN3990/3950, A610, audio, fan, charger, DP)

A source build is the robust fallback if the ABL will not load our external initramfs:

1. Fetch `linux-7.2` (or the exact ROCKNIX kernel tarball noted in `packages/linux/package.mk`).
2. Copy the DTS into `arch/arm64/boot/dts/qcom/`, add it to the Makefile.
3. Apply `projects/ROCKNIX/patches/linux` then the SM6115 device patches in numeric order.
4. Use `linux.aarch64.conf` as `.config`, set `CONFIG_INITRAMFS_SOURCE` to our initramfs (or empty
   and use an external initrd), `CONFIG_LOCALVERSION="-duo"`.
5. `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image modules qcom/sm6125-retroid-pocket-duo-lite.dtb`.

The repository's `kernel.py` already supports a `mode: "retroid"` source build for the flagship;
the Lite source path can be added under the same interface without touching the image/rootfs code.

## Changing things

| Want | Edit |
|---|---|
| Add a package | `configs/rootfs/packages.list` |
| Change boot args | `toolkit/duolib/build.py` `CMDLINE` |
| Change session / UI | `overlay/etc/sway/config`, `overlay/usr/local/lib/duo/duodeck.py` |
| Change panel placement | `overlay/usr/local/bin/duo-layout` |
| Change install user/password | `toolkit/duolib/config.py` `RootfsCfg` |
| Change image size | `duo image --size` |
| Pin the hardware base | `duo.json` `kernel.rocknix_version` / `rocknix_url` |

## Tests

```sh
python -m unittest discover -s tests -v
duo selftest
duo demo
```

`tests/` covers the Android boot image and GPT layout. Hardware checks are in BRINGUP.md.

## Cross-building applications

Anything written in a compiled language is built on the PC, not on the handheld. Building on the
device ties it up for tens of minutes and gains nothing: the target is aarch64 and the compiler does
not need the hardware. Only build on the device when the PC toolchain cannot reproduce the target
environment (for example, if a dependency has no arm64 headers or is fetched differently there).

One-time setup, inside WSL:

```sh
wsl -d Ubuntu-26.04 -u root bash toolkit/cross/setup-root.sh   # cross gcc + arm64 sysroot
wsl -d Ubuntu-26.04           bash toolkit/cross/setup-rust.sh  # rustup + aarch64 target
```

`setup-root.sh` installs `gcc-aarch64-linux-gnu` and extracts the arm64 runtime/development packages
(`libdbus-1-dev`, `libudev-dev`, `libiio-dev` and their libraries) into `/srv/duo-arm64-sysroot`.
It uses `dpkg-deb -x` rather than a chroot, because WSL2 here has no binfmt/qemu for arm64.

Build and deploy a patched InputPlumber:

```sh
wsl -d Ubuntu-26.04 bash toolkit/cross/build-inputplumber.sh   # -> out/build/inputplumber
wsl -d Ubuntu-26.04 bash toolkit/cross/deploy.sh               # scp + restart, keeps a .bak
```

The build applies every patch in `out/inputplumber-fork/` (`0001-axis-to-wheel`,
`0002-idle-backoff`) to the upstream `v0.82.0` tarball and cross-compiles with
`--target aarch64-unknown-linux-gnu`, using `PKG_CONFIG_SYSROOT_DIR` for the arm64 libraries.

## Reproducibility

- The hardware base is a nightly; pin the URL/version in `duo.json` and record the SHA256 of the tar.
- The rootfs is not bit-reproducible (Debian archive drift, machine-id, SSH host keys).
- The kernel is GPL-2.0; keep the ROCKNIX source/patchset with any redistribution.
