#!/bin/bash
# Attribution checks from the rescue SD, before touching the eMMC boot files.
# Read-only.
set -uo pipefail

echo "=== pstore (a recorded panic would settle this)"
ls -la /sys/fs/pstore 2>/dev/null | sed 's/^/  /'
for f in /sys/fs/pstore/*; do
    [ -f "$f" ] || continue
    echo "  --- $f"
    head -40 "$f" | sed 's/^/    /'
done

echo
echo "=== kexec available?"
command -v kexec || echo "  kexec: not installed"

echo
echo "=== the SD's own boot partition (the DTB that boots through this loader)"
mkdir -p /mnt/sdboot
mount -o ro /dev/mmcblk0p1 /mnt/sdboot 2>/dev/null && {
    ls -l /mnt/sdboot/ 2>/dev/null | head -8 | sed 's/^/  /'
    D=$(ls /mnt/sdboot/dtbs/qcom/*.dtb 2>/dev/null | head -1)
    echo "  sdboot dtb: ${D:-none}"
} || echo "  could not mount the SD boot partition"

echo
echo "=== properties: SD dtb vs eMMC vendor dtb vs eMMC new dtb"
mkdir -p /mnt/emmc
mount -o ro /dev/mmcblk1p88 /mnt/emmc 2>/dev/null || true

compare() {
    local f=$1 name=$2
    [ -f "$f" ] || { echo "  $name: missing"; return; }
    local size cells symbols
    size=$(stat -c %s "$f")
    # __symbols__ present?
    if strings "$f" | grep -q "__symbols__"; then symbols=yes; else symbols=no; fi
    echo "  $name: ${size} bytes, __symbols__=$symbols"
    dtc -I dtb -O dts -o "/tmp/$(basename "$name").dts" "$f" 2>/dev/null
    # the address cells of the soc bus
    awk '/soc@0 \{/{f=1} f&&/#address-cells/{print "    soc@0 #address-cells = " $3; exit}' "/tmp/$(basename "$name").dts" 2>/dev/null
}

compare "${D:-/nonexistent}" "sd-dtb"
compare /mnt/emmc/dtbs/qcom/sm6125-retroid-pocket-duo-lite.dtb.dmic "emmc-vendor-dtb"
compare /mnt/emmc/dtbs/qcom/sm6125-retroid-pocket-duo-lite.dtb "emmc-new-dtb"

echo
echo "=== live device tree handed to this running kernel"
dtc -I fs -O dts /sys/firmware/devicetree/base > /tmp/live.dts 2>/dev/null && {
    echo "  live nodes: $(grep -cE '^\s*[a-zA-Z0-9_@,.-]+ \{' /tmp/live.dts)"
    grep -q "__symbols__" /tmp/live.dts && echo "  live tree has __symbols__" || echo "  live tree has no __symbols__"
    echo "  loader-added root nodes vs the SD dtb:"
    diff <(grep -oE '^\s*[a-zA-Z0-9_@,.-]+ \{' /tmp/live.dts | sed 's/^[[:space:]]*//; s/ {$//' | sort -u) \
         <(grep -oE '^\s*[a-zA-Z0-9_@,.-]+ \{' /tmp/sd-dtb.dts 2>/dev/null | sed 's/^[[:space:]]*//; s/ {$//' | sort -u) \
         | grep '^[<>]' | head -15 | sed 's/^/    /'
} || echo "  could not read the live tree"

umount /mnt/emmc 2>/dev/null
umount /mnt/sdboot 2>/dev/null
echo DONE
