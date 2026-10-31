#!/bin/bash
# Install the fdtput-patched vendor DTB on the eMMC, keeping every fallback.
#
# Run from the rescue SD. Boots must then use the internal boot source.
set -euo pipefail
NEW=/tmp/dtb-vendor-dmic-fdtput.dtb
FAT=/dev/mmcblk1p88

[ -f "$NEW" ] || { echo "missing $NEW"; exit 1; }
mkdir -p /mnt/emmc
mount "$FAT" /mnt/emmc

D=/mnt/emmc/dtbs/qcom
TARGET=$D/sm6125-retroid-pocket-duo-lite.dtb

echo "=== current state"
ls -l --time-style=+%H:%M "$D"/ | sed 's/^/  /'

# keep the 64-bit rebuild for the record (it is the thing that broke boot)
if [ -f "$TARGET" ] && [ ! -f "$TARGET.64bit-rebuild" ]; then
    cp -p "$TARGET" "$TARGET.64bit-rebuild"
    echo "  kept the 64-bit rebuild as .64bit-rebuild"
fi

# the vendor blob must be present as the rollback
if [ ! -f "$TARGET.dmic" ]; then
    echo "  ERROR: vendor DTB fallback missing"; exit 1
fi

cp "$NEW" "${TARGET}.new"
sync
mv -f "${TARGET}.new" "$TARGET"
sync

echo
echo "=== installed"
ls -l --time-style=+%H:%M "$D"/ | sed 's/^/  /'
echo "  active sha256: $(sha256sum "$TARGET" | awk '{print $1}')"
echo "  fallback sha256: $(sha256sum "$TARGET.dmic" | awk '{print $1}')"
echo "  active #address-cells: $(fdtget "$TARGET" /soc@0 '#address-cells' 2>/dev/null || echo '?')"
echo "  active routing: $(fdtget -t s "$TARGET" /sound audio-routing 2>/dev/null | tr ' ' ' ' | tail -c 90)"

umount /mnt/emmc
echo
echo "READY - boot the internal system"
