#!/bin/bash
# Where is the Venus node, and where is the board DTS that would enable it?
set -uo pipefail
K=$HOME/rocknix-nf/port/repo
D=$HOME/rocknix-nf/distribution

echo "=== venus in the ported kernel tree"
grep -rn "venus" "$K"/arch/arm64/boot/dts/qcom/sm6115.dtsi 2>/dev/null | head -5
echo "  dtsi files: $(ls "$K"/arch/arm64/boot/dts/qcom/sm6115*.dtsi 2>/dev/null | tr '\n' ' ')"

echo
echo "=== the commit that adds it"
for h in $(git -C "$K" log --format=%H rk-7.2.11-full); do
    s=$(git -C "$K" show -s --format=%s "$h")
    case "$s" in *venus*) echo "  $h $s"; git -C "$K" show --stat "$h" | tail -4; break;; esac
done

echo
echo "=== board dts in the ROCKNIX source tree"
find "$D" -name "*.dts" 2>/dev/null | head -20
echo "  sm6125/sm6115 dts: $(find "$D" -name 'sm61*.dts' 2>/dev/null | wc -l)"
echo "  any 'duo' in dts: $(grep -rl "duolite\|pocket-duo" "$D" --include=*.dts* 2>/dev/null | head -3)"

echo
echo "=== what device tree does the running kernel see?"
echo "  (checked separately on the device)"
