#!/bin/sh
echo "ro flag per disk:"
for d in /sys/block/mmcblk1/ro /sys/block/mmcblk1/mmcblk1p88/ro; do
    [ -f "$d" ] && echo "  $d = $(cat $d)"
done
echo "blockdev: $(blockdev --getro /dev/mmcblk1p88 2>&1)"
echo "mount table:"; grep mmcblk /proc/mounts
echo "dmesg (fat/mmc):"; dmesg | grep -iE "mmcblk1|vfat|FAT-fs" | tail -12
