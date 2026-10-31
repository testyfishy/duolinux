#!/bin/bash
# Inventory the ROCKNIX system partition: what do they ship for this hardware?
set -e
OUT="/mnt/c/Users/HTPC-Aran/Documents/Default Project/duolinux/out"
IMG="$OUT/rocknix.img"
MNT=/mnt/rnx

mkdir -p "$MNT"
if ! mountpoint -q "$MNT"; then
  mount -o loop,offset=$((32768*512)),sizelimit=$((4194304*512)) "$IMG" "$MNT" 2>/dev/null || \
    mount -o ro,loop,offset=$((32768*512)) "$IMG" "$MNT"
fi

echo "=== top level"
ls -la "$MNT" | head -30

echo "=== looking for squashfs / system images"
find "$MNT" -maxdepth 2 -type f \( -name '*.squashfs' -o -name 'SYSTEM*' -o -name '*.img' -o -name 'KERNEL' \) -printf '%p %s\n' 2>/dev/null | head -20

echo "=== boot configs"
for f in "$MNT"/extlinux/extlinux.conf "$MNT"/loader/entries/*.conf; do
  [ -f "$f" ] && { echo "--- $f"; cat "$f"; }
done

echo "=== done"
