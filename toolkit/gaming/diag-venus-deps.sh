#!/bin/bash
set -uo pipefail
K=$HOME/rocknix-nf/port/repo/arch/arm64/boot/dts/qcom
echo "=== sm6125.dtsi structure"
head -20 "$K/sm6125.dtsi" | grep -E '#include|compatible|model' 
echo "  includes (all):"; grep -n '#include' "$K/sm6125.dtsi" | head -10

echo
echo "=== labels the venus node needs, and whether sm6125.dtsi (or its includes) define them"
for lbl in gcc rpmpd apps_smmu mmnrt_virt bimc config_noc pil_video_mem venus_opp_table; do
    hits=$(grep -c "$lbl:" "$K"/sm6125.dtsi "$K"/sm6125*.dtsi "$K"/pm6125.dtsi 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
    inc=$(grep -l "$lbl:" "$K"/*.dtsi 2>/dev/null | head -1)
    printf '  %-16s nodes=%s  first=%s\n' "$lbl" "$hits" "${inc##*/}"
done

echo
echo "=== does anything define pil_video_mem / venus_opp_table anywhere in the tree?"
grep -rln "pil_video_mem\|venus_opp_table" "$K"/*.dtsi 2>/dev/null | head -5

echo
echo "=== what the mangmi boards do (they are sm6115, venus-capable)"
grep -n -i "venus" "$K"/sm6115-mangmi-air-x-mq66.dts 2>/dev/null | head -5 || echo "  none reference venus"
