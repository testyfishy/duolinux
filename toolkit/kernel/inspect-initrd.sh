#!/bin/bash
# Does the initramfs' duo-init read the device tree? If it parses reg/address
# properties, the 32->64-bit cell change is enough to lose the root device.
set -uo pipefail
mount -o ro /dev/mmcblk1p88 /mnt/emmc 2>/dev/null || true
rm -rf /tmp/ir; mkdir -p /tmp/ir
cd /tmp/ir || exit 1
zcat /mnt/emmc/initrd.img | cpio -idm --quiet 2>/dev/null || { echo "cpio failed"; exit 1; }

echo "=== initramfs contents"
ls -1 /tmp/ir | sed 's/^/  /'

echo
echo "=== duo-init: device-tree and mmc references"
grep -nE "device-tree|fdt|/soc|mmc|blkid|LABEL|partuuid|PARTUUID" /tmp/ir/duo-init 2>/dev/null | head -30

echo
echo "=== duo-init size / first lines"
wc -l /tmp/ir/duo-init 2>/dev/null
sed -n '1,25p' /tmp/ir/duo-init 2>/dev/null | sed 's/^/  /'

umount /mnt/emmc 2>/dev/null
