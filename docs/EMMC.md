# Moving the rootfs to eMMC

Status: **planned, not started.** The microSD is the bottleneck, not the CPU, and the eMMC is
dramatically faster. This document records the measurements, the method borrowed from ROCKNIX's
`installtointernal`, and the exact steps and risks.

## Why

Read-only `fio`, direct I/O, 15 s per test, p99 at 4K QD1:

| Test | microSD (`mmcblk0p2`, rootfs) | eMMC (`mmcblk1p87`) |
|---|---|---|
| 4K random QD1 | 1,317 IOPS · 0.61 ms · p99 2.01 ms | 2,884 IOPS · 0.23 ms · p99 0.79 ms |
| 4K random QD32 | 1,955 IOPS · 16.2 ms | 10,420 IOPS · 3.0 ms |
| 64K random QD1 | 14.0 MiB/s | 52.4 MiB/s |
| 128K sequential QD4 | **18.3 MiB/s** | **311 MiB/s** |

The SD interface is already at its fastest mode (`UHS-I SDR104`, 4-bit, 100 MHz), so the card is the
limiter. The eMMC runs `HS400 Enhanced Strobe`, 8-bit, 192 MHz. Sequential reads are 17x faster on
the eMMC, which is what makes application and asset loading feel slow on the card.

## Layout today

`mmcblk1` (116.5 GiB, eMMC) holds Android. The interesting partitions:

| # | Size | Name | Notes |
|---|---|---|---|
| 75 | 64 MiB | `metadata` | f2fs, Android encryption metadata |
| 86 | 12 GiB | `super` | dynamic partitions: system, vendor, product |
| 87 | 102.7 GiB | `userdata` | last partition, 188 MiB free after it, GPT holds 88 entries of which 87 are used |

`mmcblk0` (microSD) holds Debian: `p1` 512 MiB vfat (boot files, `Image.gz`, `KERNEL`, `dtbs`,
`duolinux-overlay`), `p2` 460 GiB ext4 labelled `STORAGE` (the rootfs).

Boot is `extlinux` on the FAT partition: `LINUX /KERNEL`, `FDT /dtbs/qcom/...`, `INITRD /initrd.img`,
`APPEND ... root=LABEL=STORAGE ... boot=LABEL=ROCKNIX ...`.

The ROCKNIX ABL has a boot menu (hold **Volume Down** at power-on) with *Boot mode* (Android /
Linux) and *Boot source* (SD Card / internal). It is currently set to Linux from SD Card, so
booting the internal copy means changing the source to internal; switching it back to SD Card is
the rescue path and needs no tools.

## The unavoidable trade-off

**Android userdata is reset.** f2fs cannot shrink in place (only grow), and Android's file-based
encryption means the contents cannot be copied file-by-file without the device's keys. ROCKNIX's own
tool solves it the same way: delete the partition, recreate it smaller, wipe its first 8 MiB, let
Android reformat on boot. Android remains installed and bootable; it comes up as a fresh device.

Everything else on the eMMC (`super`, boot, vbmeta, recovery) is untouched, so a reset userdata is
the only Android change.

## Method (from ROCKNIX `installtointernal`)

1. Find `userdata` and the highest partition number (`parted -m -s DEVICE print`).
2. `sgdisk --resize-table=128` — stock GPTs have no spare entries for new partitions.
3. `parted rm <userdata>`, then recreate it MiB-aligned at the same start with the new size, and
   `parted name <n> userdata`.
4. Wipe the first 8 MiB of the new userdata (`dd if=/dev/zero bs=1M count=8`).
5. Create `ROCKNIX` (vfat, flags `msftdata` + `boot`, ~512 MiB) and `STORAGE` (rest of the device).
   `mkfs.ext4 -F -L STORAGE -O ^orphan_file -m 0`.
6. Copy the boot files into `ROCKNIX` and the rootfs into `STORAGE`, then `sync`.

## Plan for this device

Preconditions: accept the Android factory reset; have the SD card available as the fallback boot
medium; do not interrupt the partition step.

```sh
# 0. Back up the partition table and confirm the plan
sgdisk --backup=/root/emmc-gpt.bin /dev/mmcblk1
sgdisk -p /dev/mmcblk1            # note userdata's start sector

# 1. Resize GPT so new entries fit
sgdisk --resize-table=128 /dev/mmcblk1

# 2. Shrink userdata to 32 GiB, same start sector
parted -s /dev/mmcblk1 unit MiB print          # userdata start, in MiB
parted -s /dev/mmcblk1 rm 87
parted -a optimal -s /dev/mmcblk1 mkpart primary ext4 <START>MiB 32768MiB
parted -s /dev/mmcblk1 name 87 userdata
dd if=/dev/zero of=/dev/mmcblk1p87 bs=1M count=8

# 3. New partitions in the remainder
sgdisk -n 0:0:+512M -t 0:0700 -c 0:ROCKNIX /dev/mmcblk1
sgdisk -n 0:0:0     -t 0:8300 -c 0:STORAGE /dev/mmcblk1
mkfs.vfat -F 32 -n ROCKNIX /dev/mmcblk1p88
mkfs.ext4 -F -q -L STORAGE -O ^orphan_file -m 0 /dev/mmcblk1p89

# 4. Boot files (mount SD p1 read-only and mirror it)
mkdir -p /mnt/rk && mount /dev/mmcblk1p88 /mnt/rk
cp -a /mnt/sdboot/. /mnt/rk/ && sync && umount /mnt/rk

# 5. Rootfs
mkdir -p /mnt/emmc && mount /dev/mmcblk1p89 /mnt/emmc
rsync -aHAX --numeric-ids --info=progress2 / /mnt/emmc/ \
      --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/run --exclude=/tmp \
      --exclude=/mnt --exclude=/media --exclude=/lost+found
sync && umount /mnt/emmc
```

Then power off, remove the SD, power on holding **Volume Down**, set *Boot source* to internal
(keeping *Boot mode* = Linux), and start. If both media carry the same `STORAGE` label the boot can be
ambiguous, which is why the card comes out.

If the internal boot does not appear, reinsert the SD, set the source back to SD Card, and nothing
is lost — the card is untouched and still boots the old system.

### Points that need care

- **Label collision.** SD `p2` and eMMC `STORAGE` would both be `STORAGE`. Either remove the card
  when booting internal (simplest) or relabel the card's rootfs (`e2label /dev/mmcblk0p2 STORAGE-SD`)
  once the card is only a rescue medium.
- **Partition numbers.** The script above assumes `userdata` is 87 and the new ones become 88/89.
  Verify with `sgdisk -p` before running; do not hardcode blindly.
- **ABL.** The ROCKNIX ABL scans for the `ROCKNIX` label and boots it; `installtointernal` ends with
  "reboot and remove the SD card", so internal boot is the expected path. Keep the SD intact as a
  rescue boot until the internal install is proven.
- **initrd.** Unchanged: it is copied with the boot files and still finds `root=LABEL=STORAGE`.
- **Backups.** Before touching the table: the GPT backup above, plus an image of the SD card if it
  is the only copy of the current system. The Android system partitions are not modified, so they do
  not need an image; userdata is going to be reset by design.

## Verification after the move

1. Boot without the SD: `findmnt /` shows `/dev/mmcblk1p89`, `lsblk` confirms the labels.
2. Re-run `out/remote/disk-bench.sh` — expect ~2.8k IOPS 4K QD1 and >300 MiB/s sequential.
3. Boot Android from the ABL menu and confirm it comes up to setup (fresh userdata, 32 GiB).
4. Measure application start-up before and after (e.g. `systemd-analyze`, Firefox cold start).

## If it goes wrong

- The SD card still boots the old system: reinsert it and boot.
- Restore the table with `sgdisk --load-backup=/root/emmc-gpt.bin /dev/mmcblk1` if the partition step
  was interrupted (this does not restore Android data, which was reset deliberately).
- Android can always be restored with the vendor firmware image; the system partitions were never
  written.
