#!/bin/sh
# Retry the KERNEL swap after clearing stale read-only mounts of the same device
# (a second mount of one block device inherits the first mount's ro flag).
set -e
umount /mnt/f 2>/dev/null || true
umount /mnt/f 2>/dev/null || true
umount /mnt/boot 2>/dev/null || true
mkdir -p /mnt/boot
mount /dev/mmcblk1p88 /mnt/boot
if ! touch /mnt/boot/.rwtest 2>/dev/null; then
    echo "still ro, remounting rw"
    mount -o remount,rw /mnt/boot
    touch /mnt/boot/.rwtest
fi
rm -f /mnt/boot/.rwtest
echo "  mounted: $(grep ' /mnt/boot ' /proc/mounts | cut -d' ' -f4)"

cd /mnt/boot
[ -f KERNEL.720nf ] || cp -p KERNEL KERNEL.720nf
[ -f initrd.img.720nf ] || cp -p initrd.img initrd.img.720nf
cp /tmp/KERNEL-7.2.11-nf KERNEL
sync
echo "=== after"
echo "  KERNEL        $(stat -c %s KERNEL) $(md5sum KERNEL | cut -d' ' -f1)"
echo "  KERNEL.720nf  $(stat -c %s KERNEL.720nf) $(md5sum KERNEL.720nf | cut -d' ' -f1)"
echo "  KERNEL.720    $(stat -c %s KERNEL.720) (original 7.2.0)"
echo "  free:         $(df -h /mnt/boot | tail -1 | awk '{print $4}')"
echo "  module trees: $(ls /lib/modules | tr '\n' ' ')"
cd /
umount /mnt/boot
echo "INSTALLED"
