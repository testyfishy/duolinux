#!/bin/sh
set -u
B=$(findfs LABEL=ROCKNIX 2>/dev/null)
mkdir -p /mnt/fat
mount "$B" /mnt/fat 2>/dev/null
echo "boot part: $B"
df -h /mnt/fat | tail -1
echo "KERNEL magic:"
head -c 64 /mnt/fat/KERNEL | od -An -c | head -2
echo "initrd modules count:"
rm -rf /tmp/ird && mkdir -p /tmp/ird && cd /tmp/ird
(zcat /mnt/fat/initrd.img 2>/dev/null || cat /mnt/fat/initrd.img) | cpio -it 2>/dev/null | grep -cE '\.ko$|lib/modules'
echo "zram: $(zramctl --noheadings --output NAME,ALGORITHM,DISKSIZE 2>/dev/null | head -1)"
