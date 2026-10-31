#!/bin/bash
set -uo pipefail
K=$HOME/rocknix-nf/port/repo
B=$K/include/dt-bindings/clock/qcom,gcc-sm6125.h
echo "=== venus clocks in the sm6125 gcc binding"
for c in GCC_VIDEO_VENUS_CTL_CLK GCC_VIDEO_AHB_CLK GCC_VENUS_CTL_AXI_CLK GCC_VIDEO_THROTTLE_CORE_CLK GCC_VIDEO_VCODEC0_SYS_CLK GCC_VCODEC0_AXI_CLK GCC_VENUS_GDSC GCC_VCODEC0_GDSC; do
    printf '  %-32s %s\n' "$c" "$(grep -c "define $c" "$B")"
done

echo
echo "=== rpmhpd SM6115_VDDCX"
grep -c "SM6115_VDDCX" "$K/include/dt-bindings/power/qcom-rpmpd.h"

echo
echo "=== does the sm6125 clock driver expose these?"
grep -c "VIDEO_VENUS_CTL_CLK\|VENUS_GDSC\|VCODEC0" "$K/drivers/clk/qcom/gcc-sm6125.c"

echo
echo "=== does sm6125.dtsi already describe venus-related power domains?"
grep -n "venus\|vcodec" "$K/arch/arm64/boot/dts/qcom/sm6125.dtsi" | head -5 || echo "  none"

echo
echo "=== driver table for the compatible this board would use"
grep -n "qcm2290-venus\|sm6115-venus" "$K/drivers/media/platform/qcom/venus/core.c" | head -5
