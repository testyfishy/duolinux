#!/bin/bash
set -u
S=/mnt/rnx/SYSTEM
MNT=/mnt/rnx
OUT="/mnt/c/Users/user/Documents/Default Project/duolinux/out/rnx-port"

echo "=== our DTB vs ROCKNIX's dtbs dir"
ls -l "$MNT/dtbs" | head -20
md5sum "$MNT"/dtbs/*.dtb 2>/dev/null | head -10
echo "ours:"
md5sum "/mnt/c/Users/user/Documents/Default Project/duolinux/out/rnx-port/extract/usr/lib/firmware"/*.dtb 2>/dev/null || true
md5sum /tmp/duo.dtb 2>/dev/null || true

echo "=== who mentions the bridge / duo lite inside their system"
unsquashfs -ll "$S" 2>/dev/null | awk '{print $NF}' | grep -viE '\.(so|ko|bin|png|jpg|ttf|mo|pyc)' | head -0
mkdir -p "$OUT"/grep
for pat in wl818s duolite duo-lite 'second screen' essway; do
  echo "-- searching file names for: $pat"
  unsquashfs -ll "$S" 2>/dev/null | awk '{print $NF}' | grep -i -- "$pat" | head -8
done

echo "=== kernel-overlays structure"
unsquashfs -ll "$S" 2>/dev/null | awk '{print $NF}' | grep -E 'kernel-overlays/[^/]+/?$' | head -20

echo "=== sway / essway configs"
unsquashfs -ll "$S" 2>/dev/null | awk '{print $NF}' | grep -iE 'sway|essway' | head -30
