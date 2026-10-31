#!/bin/bash
set -uo pipefail
K=$HOME/rocknix-nf/port/repo
V=$K/drivers/media/platform/qcom/venus

echo "=== clocks the venus driver requires (by name)"
grep -n "venus_clk_names\|core\"\|iface\|vcodec0_core" "$V/core.c" | head -8
echo "  resource struct:"
sed -n '/struct venus_resources/,/};/p' "$V/core.h" | head -40

echo
echo "=== are those clocks in the sm6125 gcc binding?"
B=$K/include/dt-bindings/clock/qcom,gcc-sm6125.h
for c in GCC_VIDEO_VENUS_CTL_CLK GCC_VIDEO_AHB_CLK GCC_VENUS_CTL_AXI_CLK GCC_VIDEO_THROTTLE_CORE_CLK GCC_VIDEO_VCODEC0_SYS_CLK GCC_VCODEC0_AXI_CLK; do
    printf '  %-32s %s\n' "$c" "$(grep -c "define $c " "$B" 2>/dev/null || echo 0)"
done

echo
echo "=== power domains in the sm6125 binding / rpmhpd"
grep -c "GCC_VENUS_GDSC\|GCC_VCODEC0_GDSC" "$K/include/dt-bindings/clock/qcom,gcc-sm6125.h" 2>/dev/null
grep -c "SM6115_VDDCX" "$K/include/dt-bindings/power/qcom-rpmpd.h" 2>/dev/null

echo
echo "=== does the driver need memory-region / interconnects?"
grep -n "memory-region\|of_reserved_mem\|interconnect" "$V/core.c" | head -6
echo "  iommu: $(grep -c iommu "$V/core.c")"
