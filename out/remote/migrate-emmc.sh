#!/bin/sh
# Prepare the eMMC for a Debian install: shrink Android userdata to 32 GiB,
# create ROCKNIX (boot) and STORAGE (rootfs) partitions, and copy everything.
#
# Destructive: Android userdata is reset, as ROCKNIX installtointernal does.
# The SD card is NOT modified, so it remains the boot medium and the rescue
# path until the ABL boot source is switched to internal.
#
# Run only after the GPT/metadata/misc/boot backups are copied off-device.
set -eu

DISK=/dev/mmcblk1
UD=87
SDBOOT=/dev/mmcblk0p1
SIZE_32G=67108864          # sectors
NEW_BOOT=88
NEW_ROOT=89

fail() { echo "ABORT: $*" >&2; exit 1; }

[ -b "$DISK" ] || fail "$DISK is not a block device"
[ -b /dev/mmcblk1p$UD ] || fail "userdata p$UD missing"

echo "=== identity"
sgdisk -i $UD "$DISK" | sed -n '1,8p'
START=$(sgdisk -i $UD "$DISK" | awk -F': ' '/First sector/{print $2}' | awk '{print $1}')
END=$((START + SIZE_32G - 1))
TYPE=$(sgdisk -i $UD "$DISK" | awk -F': ' '/Partition GUID code/{print $2}' | awk '{print $1}')
UUID=$(sgdisk -i $UD "$DISK" | awk -F': ' '/Partition unique GUID/{print $2}' | awk '{print $1}')
LAST=$(sgdisk -p "$DISK" | awk '/^ +87 /{print $1}')
[ "$LAST" = "87" ] || fail "partition 87 is not the last one; layout changed"
[ -n "$START" ] && [ -n "$TYPE" ] && [ -n "$UUID" ] || fail "could not read userdata identity"
echo "start=$START end=$END type=$TYPE uuid=$UUID"

if [ -b "/dev/mmcblk1p$NEW_ROOT" ]; then
    fail "p$NEW_ROOT already exists - migration already ran"
fi

echo "=== resize GPT and repartition"
sgdisk --resize-table=128 "$DISK"
sgdisk -d $UD \
       -n $UD:$START:$END -t $UD:"$TYPE" -u $UD:"$UUID" -c $UD:userdata \
       -n $NEW_BOOT:0:+512M -t $NEW_BOOT:0700 -c $NEW_BOOT:ROCKNIX \
       -n $NEW_ROOT:0:0     -t $NEW_ROOT:8300 -c $NEW_ROOT:STORAGE \
       "$DISK"
partx -u "$DISK" 2>/dev/null || true
udevadm settle 2>/dev/null || true
lsblk -o NAME,SIZE,PARTLABEL "$DISK" | tail -6

UD_SECTORS=$(( $(blockdev --getsz /dev/mmcblk1p$UD) ))
echo "userdata now $UD_SECTORS sectors (~$(( UD_SECTORS / 2097152 )) GiB)"
[ "$UD_SECTORS" -gt 30000000 ] || fail "userdata looks too small ($UD_SECTORS sectors)"
[ "$UD_SECTORS" -lt 80000000 ] || fail "userdata looks too large ($UD_SECTORS sectors)"

echo "=== reset Android userdata + metadata"
wipefs -a /dev/mmcblk1p$UD >/dev/null 2>&1 || true
dd if=/dev/zero of=/dev/mmcblk1p$UD bs=1M count=8 status=none
dd if=/dev/zero of=/dev/mmcblk1p75 bs=1M count=64 status=none
sync

echo "=== filesystems"
mkfs.vfat -F 32 -n ROCKNIX /dev/mmcblk1p$NEW_BOOT >/dev/null
mkfs.ext4 -F -q -L STORAGE -O ^orphan_file -m 0 /dev/mmcblk1p$NEW_ROOT
e2fsck -fn /dev/mmcblk1p$NEW_ROOT >/dev/null && echo "ext4 clean"

echo "=== boot files"
mkdir -p /mnt/rk /mnt/emmc /mnt/src
mount /dev/mmcblk1p$NEW_BOOT /mnt/rk
if ! mountpoint -q /mnt/sdboot; then
    mkdir -p /mnt/sdboot
    mount -o ro "$SDBOOT" /mnt/sdboot
fi
cp -a /mnt/sdboot/. /mnt/rk/
sync
if diff -r /mnt/sdboot /mnt/rk >/tmp/bootdiff.log 2>&1; then
    echo "boot partitions identical"
else
    echo "WARNING: boot partitions differ:"; head -10 /tmp/bootdiff.log
fi
umount /mnt/rk

echo "=== rootfs (this takes several minutes on the card)"
mount /dev/mmcblk1p$NEW_ROOT /mnt/emmc
mount --bind / /mnt/src
rsync -aHAXS --numeric-ids /mnt/src/ /mnt/emmc/
for d in proc sys dev run tmp; do mkdir -p "/mnt/emmc/$d"; done
mkdir -p /mnt/emmc/mnt /mnt/emmc/media
chmod 1777 /mnt/emmc/tmp
sync
umount /mnt/src

echo "=== verify the copy"
e2fsck -fn /dev/mmcblk1p$NEW_ROOT >/dev/null && echo "ext4 clean after copy"
df -h /mnt/emmc | tail -1
ls /mnt/emmc/etc/fstab /mnt/emmc/usr/bin/sudo >/dev/null && echo "rootfs looks complete"
umount /mnt/emmc
udevadm settle 2>/dev/null || true

echo "=== done; final state"
lsblk -o NAME,SIZE,PARTLABEL /dev/mmcblk1 | tail -6
blkid /dev/mmcblk1p$NEW_BOOT /dev/mmcblk1p$NEW_ROOT
echo
echo "SD card untouched and still the boot medium."
echo "To finish: power off, remove the SD, hold Volume Down at power-on,"
echo "set Boot mode=Linux and Boot source=internal, then Start."
