#!/bin/bash
set -uo pipefail
K=$HOME/rocknix-nf/port/repo/drivers/clk/qcom
echo "=== venus blocks in gcc-sm6115.c (the sibling that has them)"
grep -n -B2 -A12 "VIDEO_VENUS_CTL\|VENUS_GDSC\|VCODEC0_GDSC\|venus_clk_src" "$K/gcc-sm6115.c" | head -60

echo
echo "=== video-related blocks already present in gcc-sm6125.c"
grep -n "video\|venus\|vcodec" "$K/gcc-sm6125.c" | head -20

echo
echo "=== register bases: does sm6125 have the same video clock region?"
grep -n "0x7[0-9a-f]\{4\}\|0x6[0-9a-f]\{4\}" "$K/gcc-sm6125.c" | grep -i video | head -10
echo "  sm6115 video regs:"
grep -n -A3 "GCC_VIDEO_VENUS_CTL_CLK\|GCC_VENUS_CTL_AXI" "$K/../clk/qcom/gcc-sm6115.c" | grep -oE "0x[0-9a-f]{4,6}" | sort -u | head -8
