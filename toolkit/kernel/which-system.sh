#!/bin/sh
set -u
echo "=== identity"
echo "  cmdline: $(cat /proc/cmdline)"
echo "  root:    $(findmnt -no SOURCE /)  ($(findmnt -no FSTYPE /))"
echo "  kernel:  $(uname -r)"
echo "  modules: $(ls /lib/modules | tr '\n' ' ')"

echo
echo "=== disks"
lsblk -o NAME,SIZE,LABEL,FSTYPE,MOUNTPOINT | grep -E "mmcblk|NAME"

echo
echo "=== kernel images on both FATs"
for d in mmcblk0p1 mmcblk1p88; do
    mkdir -p /tmp/m
    mount -o ro "/dev/$d" /tmp/m 2>/dev/null
    echo "  /dev/$d:"; ls -l /tmp/m/KERNEL* 2>/dev/null | awk '{print "    "$5" "$9}'
    echo "    extlinux: $(grep -m1 APPEND /tmp/m/extlinux/extlinux.conf 2>/dev/null | cut -c1-90)"
    umount /tmp/m 2>/dev/null
done

echo
echo "=== which root does each initrd resolve?"
echo "  (eMMC initrd uses LABEL=LINUXROOT, SD initrd uses LABEL=STORAGE)"

echo
echo "=== is the SD card even inserted?"
echo "  $(lsblk -dn -o NAME,SIZE | tr '\n' ' ')"
