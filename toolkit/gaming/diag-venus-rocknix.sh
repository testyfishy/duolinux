#!/bin/bash
set -uo pipefail
P=$HOME/rocknix-nf/distribution/projects/ROCKNIX
echo "=== any ROCKNIX patch touching gcc-sm6125 / venus clocks"
grep -rln "gcc-sm6125\|VIDEO_VENUS_CTL\|VENUS_GDSC" "$P"/devices/SM6115/patches/linux/ 2>/dev/null | head -10

echo
echo "=== venus-related patches in the SM6115 series"
ls "$P"/devices/SM6115/patches/linux/ | grep -i venus || echo "  only 0015 (dts)"

echo
echo "=== what 0015 actually contains (does it touch clocks?)"
grep -E '^\+\+\+ b/' "$P"/devices/SM6115/patches/linux/0015-*.patch

echo
echo "=== does the sm6115 clock driver have the venus clocks this board lacks?"
K=$HOME/rocknix-nf/port/repo
for f in gcc-sm6115.c gcc-sm6125.c; do
    echo "  $f: venus=$(grep -c 'VIDEO_VENUS\|VENUS_GDSC\|VCODEC0' "$K/drivers/clk/qcom/$f")"
done

echo
echo "=== is the device really sm6125 or sm6115? (board dts compatible)"
grep -m2 "compatible" "$P"/devices/SM6115/linux/dts/qcom/sm6125-retroid-pocket-duo-lite.dts
