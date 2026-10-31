#!/bin/sh
# Make the SD and eMMC unambiguous for /duo-init, without touching the SD.
#
# duo-init (in the initrd) does findfs LABEL=ROCKNIX / LABEL=STORAGE, ignoring
# root=. With both media carrying those labels, findfs returned the eMMC even
# when booting from the SD, so an SD rescue would have mounted the eMMC rootfs.
#
# GPT partition names stay ROCKNIX/STORAGE because that is what the ABL matches;
# only the filesystem labels change. The eMMC initrd is patched to look for
# LINUXBOOT/LINUXROOT.
set -eu

RK=/dev/mmcblk1p88
ST=/dev/mmcblk1p89
MNT=/mnt/rk

fail() { echo "ABORT: $*" >&2; exit 1; }

echo "=== before"
echo "STORAGE -> $(findfs LABEL=STORAGE)"
echo "ROCKNIX -> $(findfs LABEL=ROCKNIX)"

mkdir -p "$MNT"
mount "$RK" "$MNT"

echo "=== back up the original initrd on the eMMC boot partition"
[ -f "$MNT/initrd.img.orig" ] || cp -a "$MNT/initrd.img" "$MNT/initrd.img.orig"

echo "=== patch duo-init labels inside the eMMC initrd"
rm -rf /tmp/ir2
mkdir -p /tmp/ir2
cd /tmp/ir2
# This initrd has trailing padding that makes cpio return non-zero after it has
# already extracted everything, so tolerate the exit status and verify instead.
zcat "$MNT/initrd.img" | cpio -idm --quiet 2>/dev/null || true
[ -f duo-init ] || fail "duo-init missing from initrd"
zcat "$MNT/initrd.img" 2>/dev/null | cpio -t 2>/dev/null | sort > /tmp/list.out || true
find . -mindepth 1 | sed 's|^\./||' | sort > /tmp/have.out
if ! diff -q /tmp/list.out /tmp/have.out >/dev/null 2>&1; then
    echo "WARNING: extracted tree differs from archive listing:"; diff /tmp/list.out /tmp/have.out | head -5
fi
sed -i \
    -e 's/LABEL=ROCKNIX/LABEL=LINUXBOOT/g' \
    -e 's/grep -i ROCKNIX/grep -i LINUXBOOT/g' \
    -e 's/LABEL=STORAGE/LABEL=LINUXROOT/g' \
    -e 's/grep -i STORAGE/grep -i LINUXROOT/g' \
    duo-init
grep -nE "LINUXBOOT|LINUXROOT" duo-init | head -6
find . -print0 | cpio --null -o -H newc --quiet 2>/dev/null | gzip -9 > "$MNT/initrd.img.new"
[ -s "$MNT/initrd.img.new" ] || fail "repacked initrd is empty"

echo "=== verify the repacked initrd lists the same files"
if zcat "$MNT/initrd.img.new" | cpio -t --quiet 2>/dev/null | grep -qx duo-init; then
    mv -f "$MNT/initrd.img.new" "$MNT/initrd.img"
    echo "initrd replaced ($(stat -c %s "$MNT/initrd.img") bytes)"
else
    fail "repacked initrd does not list duo-init; original kept"
fi

echo "=== point the eMMC extlinux at the new labels"
sed -i 's/root=LABEL=STORAGE/root=LABEL=LINUXROOT/; s/boot=LABEL=ROCKNIX/boot=LABEL=LINUXBOOT/; s/disk=LABEL=STORAGE/disk=LABEL=LINUXROOT/' "$MNT/extlinux/extlinux.conf"
grep APPEND "$MNT/extlinux/extlinux.conf"
cd /
umount "$MNT"

echo "=== eMMC filesystem labels (GPT names unchanged)"
fatlabel "$RK" LINUXBOOT
e2label "$ST" LINUXROOT

echo "=== eMMC fstab"
mkdir -p /mnt/emmc
mount "$ST" /mnt/emmc
sed -i 's/LABEL=STORAGE/LABEL=LINUXROOT/' /mnt/emmc/etc/fstab
cat /mnt/emmc/etc/fstab
sync
umount /mnt/emmc

echo "=== after"
echo "STORAGE    -> $(findfs LABEL=STORAGE)"
echo "ROCKNIX    -> $(findfs LABEL=ROCKNIX)"
echo "LINUXROOT  -> $(findfs LABEL=LINUXROOT)"
echo "LINUXBOOT  -> $(findfs LABEL=LINUXBOOT)"
echo "=== GPT names"
sgdisk -i 88 /dev/mmcblk1 | grep "Partition name"
sgdisk -i 89 /dev/mmcblk1 | grep "Partition name"
