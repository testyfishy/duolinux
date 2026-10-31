#!/bin/bash
set -uo pipefail
K=$HOME/rocknix-nf/port/repo/drivers/clk/qcom
echo "=== sm6125 video clock registers"
grep -n -A4 "gcc_video_ahb_clk\|gcc_video_axi0_clk\|gcc_video_throttle_core_clk" "$K/gcc-sm6125.c" | grep -E "halt_reg|name =" | head -12

echo
echo "=== is the 0x58000 region already used in gcc-sm6125.c?"
grep -oE "0x58[0-9a-f]{3}" "$K/gcc-sm6125.c" | sort -u | head -20

echo
echo "=== GDSCs in gcc-sm6125.c (names only)"
grep -E "^\s+\.name = \"gcc_.*gdsc\"" "$K/gcc-sm6125.c" | head -12

echo
echo "=== sm6115 venus GDSC definitions (what would be added)"
grep -n -A18 "gcc_venus_gdsc\|gcc_vcodec0_gdsc" "$K/gcc-sm6115.c" | head -45

echo
echo "=== sm6115 venus clock IDs in its binding"
grep -nE "VIDEO_VENUS_CTL_CLK|VENUS_CTL_AXI|VIDEO_VCODEC0_SYS|VCODEC0_AXI|VENUS_GDSC|VCODEC0_GDSC" \
    "$HOME/rocknix-nf/port/repo/include/dt-bindings/clock/qcom,gcc-sm6115.h"
