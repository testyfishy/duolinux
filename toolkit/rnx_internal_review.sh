#!/bin/bash
set -u
S=/mnt/rnx/SYSTEM
OUT="/mnt/c/Users/HTPC-Aran/Documents/Default Project/duolinux/out/rnx-port/internal"
mkdir -p "$OUT"

echo "=== candidate internal-install files"
unsquashfs -ll "$S" 2>/dev/null | awk '{print $NF}' | grep -iE 'internal|install.*(disk|emmc|storage)|migrate' | grep -viE '\.(png|svg|mo|pyc|ttf)' | head -20

echo
echo "=== anything that mentions userdata or resize"
LIST=$(unsquashfs -ll "$S" 2>/dev/null | awk '{print $NF}' | grep -E 'usr/bin/|usr/sbin/|usr/share/rocknix|usr/lib/autostart' | sed 's|^squashfs-root/||')
# shellcheck disable=SC2086
unsquashfs -d "$OUT/extract" "$S" $LIST >/dev/null 2>&1 || true
grep -rl -iE 'userdata|resize2fs|resize.f2fs|sgdisk|sfdisk' "$OUT/extract" 2>/dev/null | head -15
