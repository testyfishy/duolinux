#!/bin/bash
# Where does Android still live? Read-only inspection of the block devices so we
# can pull the vendor DTB and audio configuration offline.
set -uo pipefail
echo "=== block devices"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,PARTLABEL 2>/dev/null | sed 's/^/  /'

echo
echo "=== partitions with android-looking labels"
ls /dev/disk/by-partlabel 2>/dev/null | grep -iE "boot|dtbo|vendor|super|system|modem|persist|a$|_a$" | head -30

echo
echo "=== all partlabels (first 60)"
ls /dev/disk/by-partlabel 2>/dev/null | head -60

echo
echo "=== mounts"
findmnt -rno TARGET,SOURCE,FSTYPE | head -12 | sed 's/^/  /'
