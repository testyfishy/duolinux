#!/bin/bash
# Second-line backup onto the USB drive, taken from the rescue SD.
#
# Layout on the USB (inside duo-backup-<date>/):
#   sd-boot.tar.xz    - the SD's FAT boot partition (kernel, DTB, initrd, extlinux)
#   sd-rootfs.tar.zst - the rescue rootfs, excluding pseudo filesystems
#   emmc-boot.tar.xz  - the eMMC boot partition (working KERNEL, KERNEL.prev,
#                       dtbs incl. .audio/.dmic rollbacks, initrd, extlinux)
#   MANIFEST.txt      - what this is, and how to restore it
#
# Nothing is deleted from the USB; the backup lives in its own directory.
set -euo pipefail
USB=/dev/sda1
DATE=$(date +%Y%m%d-%H%M)
DEST=/mnt/usb/duo-backup-$DATE

echo "=== mounting"
mkdir -p /mnt/usb
mount "$USB" /mnt/usb
df -h /mnt/usb | tail -1

mkdir -p "$DEST"
echo "=== destination: $DEST"

echo "=== 1/3 SD boot partition"
mount "$USB" /mnt/usb 2>/dev/null || true
mkdir -p /mnt/sdboot
mount /dev/mmcblk0p1 /mnt/sdboot
tar -C /mnt/sdboot -cJf "$DEST/sd-boot.tar.xz" .
umount /mnt/sdboot

echo "=== 2/3 eMMC boot partition"
mount /dev/mmcblk1p88 /mnt/boot 2>/dev/null || true
tar -C /mnt/boot -cJf "$DEST/emmc-boot.tar.xz" .
ls -l "$DEST/emmc-boot.tar.xz"

echo "=== 3/3 rescue rootfs (this takes a few minutes)"
tar -C / \
    --exclude=./proc --exclude=./sys --exclude=./dev --exclude=./run \
    --exclude=./tmp --exclude=./mnt --exclude=./media --exclude=./lost+found \
    -cf - . | zstd -3 -T0 -q -o "$DEST/sd-rootfs.tar.zst"

cat > "$DEST/MANIFEST.txt" <<EOF
DuoLinux rescue backup, made $(date -u +%Y-%m-%dT%H:%MZ) from the rescue SD.

sd-boot.tar.xz      SD FAT boot partition (ROCKNIX label)
sd-rootfs.tar.zst   rescue rootfs (archive root = /)
emmc-boot.tar.xz    eMMC FAT boot partition: KERNEL (working), KERNEL.prev,
                    dtbs/qcom/...dtb plus .audio and .dmic rollbacks, initrd, extlinux

To restore the eMMC boot partition:
  mount /dev/mmcblk1p88 /mnt/boot
  tar -C /mnt/boot -xJf emmc-boot.tar.xz
  sync

To rebuild a rescue SD: write a fresh FAT (label ROCKNIX) and ext4 (label
STORAGE) pair, extract sd-boot and sd-rootfs onto them, then make the card
bootable the same way the original image was built (see docs/BUILD.md).
EOF

echo "=== done"
ls -lh "$DEST" | sed 's/^/  /'
umount /mnt/usb
