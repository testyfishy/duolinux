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

Preconditions: accept the Android factory reset; keep the SD card as the fallback boot medium; do not
interrupt the partition step. **Use `sgdisk` only** — mixing `parted` and `sgdisk` writes the GPT
twice and can lose the type/UUID of the userdata entry.

Recorded values (verify before running, do not trust these blindly):

| Item | Value |
|---|---|
| `userdata` start | sector 28990464 (14155.5 MiB) |
| `userdata` 32 GiB end | sector 96099327 (28990464 + 67108864 - 1) |

```sh
# 0. Identity, backups, and an off-device copy
sgdisk -i 87 /dev/mmcblk1          # note: type GUID and unique GUID
sgdisk --backup=/root/emmc-gpt.bin /dev/mmcblk1
dd if=/dev/mmcblk1p75 of=/root/emmc-backup/metadata.img bs=4M status=none
dd if=/dev/mmcblk1p6  of=/root/emmc-backup/misc.img     bs=4M status=none
dd if=/dev/mmcblk1p36 of=/root/emmc-backup/boot_a.img   bs=4M status=none
dd if=/dev/mmcblk1p87 of=/root/emmc-backup/userdata-head.img bs=1M count=16 status=none
# scp all of these to the PC (out/backups/)

# 1. Resize the table only if it has no free entries for 88 and 89
sgdisk -p /dev/mmcblk1 | grep "holds up to"    # 88 now: 87 used, one spare, so:
sgdisk --resize-table=128 /dev/mmcblk1

# 2. Shrink userdata to 32 GiB in one sgdisk call, preserving number, type and unique GUID
sgdisk -d 87 \
       -n 87:28990464:96099327 -t 87:<orig-type-guid> -u 87:<orig-unique-guid> -c 87:userdata \
       -n 88:0:+512M            -t 88:0700            -c 88:ROCKNIX \
       -n 89:0:0                -t 89:8300            -c 89:STORAGE \
       /dev/mmcblk1
partx -u /dev/mmcblk1
lsblk -o NAME,SIZE,PARTLABEL /dev/mmcblk1 | tail -5   # verify sizes BEFORE writing anything
```

`parted rm` would have let the recreated entry take the Linux-data type GUID and a new unique GUID;
Android's fstab uses by-name, but Qualcomm's bootloader/fastboot look partitions up by type GUID, so
both are preserved above.

```sh
# 3. Wipe the start of userdata and the stale encryption metadata
wipefs -a /dev/mmcblk1p87
dd if=/dev/zero of=/dev/mmcblk1p87 bs=1M count=8 status=none
dd if=/dev/zero of=/dev/mmcblk1p75 bs=1M count=64 status=none   # metadata: recreated by Android
# never touch p74 (persist): it holds device calibration that cannot be regenerated

# 4. Filesystems
mkfs.vfat -F 32 -n ROCKNIX /dev/mmcblk1p88
mkfs.ext4 -F -q -L STORAGE -O ^orphan_file -m 0 /dev/mmcblk1p89
e2fsck -fn /dev/mmcblk1p89

# 5. Boot files: mirror the SD boot partition, then compare
mkdir -p /mnt/rk /mnt/sdboot
mount /dev/mmcblk1p88 /mnt/rk
mount -o ro /dev/mmcblk0p1 /mnt/sdboot
cp -a /mnt/sdboot/. /mnt/rk/
sync
diff -r /mnt/sdboot /mnt/rk          # must be identical before removing the card

# 6. Rootfs: bind-mount / and rsync with -x (do NOT exclude the mountpoint directories,
#    rsync would then not create /proc, /sys, /dev, /run, /tmp and boot would fail)
mkdir -p /mnt/emmc /mnt/src
mount /dev/mmcblk1p89 /mnt/emmc
mount --bind / /mnt/src
rsync -aHAXS --numeric-ids /mnt/src/ /mnt/emmc/
mkdir -p /mnt/emmc/proc /mnt/emmc/sys /mnt/emmc/dev /mnt/emmc/run /mnt/emmc/tmp
chmod 1777 /mnt/emmc/tmp
sync
umount /mnt/src
e2fsck -fn /dev/mmcblk1p89
```

Notes on the copy: `-x` keeps it on the root filesystem, so `/proc`, `/sys`, `/dev`, `/run`, `/tmp`
(the tmpfs) and `/mnt` are not descended into; the empty directories are created explicitly above.
`machine-id` and `/var/lib/systemd/random-seed` are copied deliberately. No `update-initramfs` is
needed: the initrd finds the root by label. Later kernel updates must write to the eMMC `ROCKNIX`
partition, not the SD.

Then power off, remove the SD, power on holding **Volume Down**, set *Boot source* to internal
(keeping *Boot mode* = Linux), and start. If both media carry the same `STORAGE` label the boot can be
ambiguous, which is why the card comes out.

If the internal boot does not appear, reinsert the SD, set the source back to SD Card, and nothing
is lost — the card is untouched and still boots the old system.

### Points that need care

- **Label collision.** Until the SD is retired, there are two `ROCKNIX` and two `STORAGE` labels and
  the winner is undefined (ABL, udev's by-label links, `/duo-init`). Boot internal with the card out.
  Once internal boot is proven, relabel the card (`fatlabel`/`e2label` to `ROCKNIX_SD`/`STORAGE_SD`)
  and adjust its extlinux and fstab, or keep it purely as an offline backup.
- **Android metadata.** Resizing userdata without wiping `metadata` is the classic cause of a
  decryption failure loop; `fastboot -w` wipes it for that reason. It is backed up and zeroed above.
  Never touch `persist` (device calibration).
- **Partition identity.** Preserve userdata's type and unique GUID; the number stays 87 because it is
  reused after the delete.
- **ABL.** Booting internal is a boot-source choice in the ABL menu (Volume Down at power-on):
  *Boot mode* = Linux, *Boot source* = internal. Switching back to SD Card is the rescue path.
- **initrd.** Unchanged: it is copied with the boot files and still finds `root=LABEL=STORAGE`.
- **Backups.** GPT of both disks, `metadata`, `misc`, `boot_a`, and the first 16 MiB of userdata are
  in `out/backups/` off-device. The Android system partitions are not modified.


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
