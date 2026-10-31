#!/bin/bash
set -u
echo "=== internal eMMC layout (from the running system)"
ls /dev/disk/by-partlabel 2>/dev/null | head -40
echo "--- sizes of the big ones"
for p in userdata super system_a system_b metadata; do
  d=/dev/disk/by-partlabel/$p
  [ -e "$d" ] && echo "  $p -> $(readlink -f "$d") $(blockdev --getsize64 "$d" 2>/dev/null | awk '{printf "%.1f GB\n", $1/1e9}')"
done
echo "--- whole device"
lsblk -b -o NAME,SIZE,TYPE,MOUNTPOINT 2>/dev/null | grep -E 'mmcblk|NAME' | head -20
echo "--- free space check on userdata"
df -h /sys 2>/dev/null | tail -1

echo "=== ROCKNIX internal install script, if shipped"
S=/mnt/rnx/SYSTEM
unsquashfs -ll "$S" 2>/dev/null | awk '{print $NF}' | grep -iE 'installtointernal|install-internal|internal' | head -10
