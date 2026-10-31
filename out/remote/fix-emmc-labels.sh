#!/bin/sh
# Make the eMMC root unambiguous so the SD card stays a real rescue.
#
# duo-init (initrd, PID 1) ignores root= and does:
#     BOOTDEV=$(findfs LABEL=ROCKNIX)   ... blkid | grep -i ROCKNIX
#     ROOTDEV=$(findfs LABEL=STORAGE)   ... blkid | grep -i STORAGE
# With both media labelled STORAGE, it picks the eMMC - so an SD boot would
# mount the never-booted eMMC rootfs and there would be no independent rescue.
#
# This renames ONLY the eMMC root to LINUXROOT (filesystem label and GPT name,
# because the blkid fallback matches PARTLABEL too), patches only the ROOTDEV
# lookup in the eMMC initrd, and points that initrd's extlinux at it.
#
# p88 keeps FAT label and GPT name ROCKNIX: how the ABL finds the boot
# partition is unknown, and a duplicate ROCKNIX only means /boot might come
# from the identical SD copy, which is harmless.
set -eu

RK=/dev/mmcblk1p88
ST=/dev/mmcblk1p89
MNT=/mnt/rk
EM=/mnt/emmc

fail() { echo "ABORT: $*" >&2; exit 1; }

echo "=== before"
echo "STORAGE   -> $(findfs LABEL=STORAGE 2>/dev/null)"
echo "ROCKNIX   -> $(findfs LABEL=ROCKNIX 2>/dev/null)"

mkdir -p "$MNT" "$EM"
mountpoint -q "$MNT" || mount "$RK" "$MNT"

echo "=== keep the original initrd"
[ -f "$MNT/initrd.img.orig" ] || cp -a "$MNT/initrd.img" "$MNT/initrd.img.orig"
echo "original: $(file -b "$MNT/initrd.img")"

echo "=== unpack, patch ROOTDEV only, repack"
rm -rf /tmp/ir2 && mkdir -p /tmp/ir2 && cd /tmp/ir2
# Trailing padding makes cpio exit non-zero after extracting everything.
zcat "$MNT/initrd.img" | cpio -idm --quiet 2>/dev/null || true
[ -f duo-init ] || fail "duo-init missing from initrd"
cp -a duo-init duo-init.old
zcat "$MNT/initrd.img" 2>/dev/null | cpio -t 2>/dev/null | sort > /tmp/list.old || true

sed -i -e 's/LABEL=STORAGE/LABEL=LINUXROOT/g' -e 's/grep -i STORAGE/grep -i LINUXROOT/g' duo-init
chmod +x duo-init

echo "--- duo-init diff (only the root label should change)"
diff -u duo-init.old duo-init || true
if grep -q "LABEL=ROCKNIX" duo-init; then echo "ok    BOOTDEV lookup untouched"; else echo "WARN  BOOTDEV lookup changed"; fi

find . -print0 | sort -z | cpio --null -o -H newc --quiet 2>/dev/null | gzip -9 > "$MNT/initrd.img.new"
[ -s "$MNT/initrd.img.new" ] || fail "repacked initrd empty"

echo "--- entry list comparison"
zcat "$MNT/initrd.img.new" 2>/dev/null | cpio -t 2>/dev/null | sort > /tmp/list.new || true
if diff -q /tmp/list.old /tmp/list.new >/dev/null 2>&1; then
    echo "ok    entry lists identical ($(wc -l < /tmp/list.new) entries)"
else
    echo "entries differ:"; diff /tmp/list.old /tmp/list.new | head -10
fi
mv -f "$MNT/initrd.img.new" "$MNT/initrd.img"
echo "new initrd: $(stat -c %s "$MNT/initrd.img") bytes, $(file -b "$MNT/initrd.img")"

echo "=== extlinux: root and disk -> LINUXROOT, boot stays ROCKNIX"
sed -i 's/root=LABEL=STORAGE/root=LABEL=LINUXROOT/; s/disk=LABEL=STORAGE/disk=LABEL=LINUXROOT/' "$MNT/extlinux/extlinux.conf"
grep APPEND "$MNT/extlinux/extlinux.conf"
cd / && umount "$MNT"

echo "=== rename the eMMC root (filesystem label and GPT name)"
mountpoint -q "$EM" && umount "$EM"
e2label "$ST" LINUXROOT
sgdisk -c 89:LINUXROOT /dev/mmcblk1 >/dev/null
partx -u /dev/mmcblk1 2>/dev/null || true
udevadm settle 2>/dev/null || true

echo "=== fstab on the eMMC root"
mount "$ST" "$EM"
sed -i 's/LABEL=STORAGE/LABEL=LINUXROOT/g' "$EM/etc/fstab"
cat "$EM/etc/fstab"
echo "--- other STORAGE references under /etc:"
grep -rIl 'STORAGE' "$EM/etc" 2>/dev/null | head -10 || echo "none"
sync
umount "$EM"

echo "=== after"
echo "STORAGE   -> $(findfs LABEL=STORAGE 2>/dev/null)   (should be the SD card)"
echo "LINUXROOT -> $(findfs LABEL=LINUXROOT 2>/dev/null) (should be mmcblk1p89)"
echo "ROCKNIX   -> $(findfs LABEL=ROCKNIX 2>/dev/null)"
blkid "$ST"
sgdisk -i 89 /dev/mmcblk1 | grep "Partition name"
