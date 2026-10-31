#!/bin/bash
# What does the Venus node look like, and what would rebuilding the board DTB change?
set -uo pipefail
K=$HOME/rocknix-nf/port/repo
D=$HOME/rocknix-nf/distribution/projects/ROCKNIX/devices/SM6115/linux/dts/qcom
BD=$D/sm6125-retroid-pocket-duo-lite.dts

echo "=== venus node in our dtsi"
sed -n '/video-codec@5a00000/,/^\t\t};/p' "$K/arch/arm64/boot/dts/qcom/sm6115.dtsi" | head -40

echo
echo "=== board dts: what it includes"
grep -nE "^#include|^/dts-v1|model|compatible" "$BD" | head -12
echo "  size: $(wc -l < "$BD") lines"

echo
echo "=== does the board dts touch venus/video at all?"
grep -n -iE "venus|video-codec|video" "$BD" | head -10 || echo "  no mention"

echo
echo "=== does the shipped DTB contain the node?"
if [ -f /tmp/dtb-check/board.dts ]; then
    echo "  video-codec nodes: $(grep -c 'video-codec' /tmp/dtb-check/board.dts)"
    grep -n "video-codec" /tmp/dtb-check/board.dts | head -3
else
    echo "  no cached decompile"
fi

echo
echo "=== do the other SM6115 boards enable it?"
grep -l "venus" "$D"/sm6115-mangmi-*.dts 2>/dev/null | head -3
grep -n "venus" "$D"/sm6115-mangmi-air-x-mq66.dts 2>/dev/null | head -5
