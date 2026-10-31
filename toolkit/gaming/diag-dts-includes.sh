#!/bin/bash
set -uo pipefail
K=$HOME/rocknix-nf/port/repo
F=$K/arch/arm64/boot/dts/qcom/sm6125-retroid-pocket-duo-lite.dts
echo "=== quoted includes in the board dts"
grep -n '#include "' "$F" | head -10
echo
echo "=== which dtsi defines the venus label, and is it reachable?"
grep -rln "venus: video-codec" "$K/arch/arm64/boot/dts/qcom/" | head -3
echo "  sm6125.dtsi exists: $(ls "$K"/arch/arm64/boot/dts/qcom/sm6125.dtsi 2>/dev/null || echo no)"
echo "  sm6125.dtsi includes: $(grep -n '#include "' "$K"/arch/arm64/boot/dts/qcom/sm6125.dtsi 2>/dev/null | head -5)"
echo
echo "=== does the SoC dtsi the board uses contain venus at all?"
for f in "$K"/arch/arm64/boot/dts/qcom/sm6115.dtsi "$K"/arch/arm64/boot/dts/qcom/sm6125.dtsi; do
    [ -f "$f" ] || continue
    echo "  $(basename "$f"): venus node=$(grep -c 'video-codec@5a00000' "$f") lines=$(wc -l < "$f")"
done
