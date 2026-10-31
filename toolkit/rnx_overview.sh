#!/bin/bash
# Inventory the official ROCKNIX SM6115 image: what do they have that we lack?
set -e
OUT="/mnt/c/path/to/duolinux/out"
cd "$OUT"

if [ ! -f rocknix.img ]; then
  echo "=== decompressing (1.3 GB -> raw)"
  gzip -dc rocknix-sm6115.img.gz > rocknix.img
fi
echo "=== image size:"; ls -l rocknix.img

echo "=== partition table:"
sfdisk -d rocknix.img 2>/dev/null || true

echo "=== file system signatures:"
blkid -p -o full rocknix.img 2>/dev/null || true
for off in $(sfdisk -d rocknix.img 2>/dev/null | awk '/start=/{for(i=1;i<=NF;i++) if($i ~ /^start=/){gsub(/[^0-9]/,"",$i); print $i}}'); do
  echo "-- partition at sector $off: $(blkid -p -o value -s TYPE -O $((off*512)) rocknix.img 2>/dev/null || echo unknown)"
done
