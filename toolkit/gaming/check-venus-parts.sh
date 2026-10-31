#!/bin/sh
set -u
K=$HOME/rocknix-nf/port/repo
D=$HOME/rocknix-nf/distribution

echo "=== venus node in the kernel tree (patch 0015)"
grep -rn "venus" "$K"/arch/arm64/boot/dts/qcom/sm6115.dtsi "$K"/arch/arm64/boot/dts/qcom/sm6125*.dtsi 2>/dev/null | head -8
echo "  node block:"
grep -n -A12 "video-codec\|venus" "$K/arch/arm64/boot/dts/qcom/sm6115.dtsi" 2>/dev/null | head -20

echo
echo "=== does the board dts exist in the ROCKNIX source?"
find "$D" -iname "*duolite*" -o -iname "*retroid*" 2>/dev/null | head -10
echo "  (dts dirs):"
find "$D" -path "*dts*" -name "*.dts" 2>/dev/null | grep -iE "sm6125|sm6115" | head -10

echo
echo "=== venus in the running board DTB?"
grep -c "venus" /tmp/dtb-check/board.dts 2>/dev/null || echo "  (board.dts not cached)"
grep -n "venus\|video-codec" /tmp/dtb-check/board.dts 2>/dev/null | head -5

echo
echo "=== the module itself"
modinfo qcom_venus 2>/dev/null | head -6 || echo "  modinfo: not found in /lib/modules"
find /lib/modules -name "*venus*" 2>/dev/null | head -3
echo "  deps: $(modprobe --show-depends qcom_venus 2>&1 | head -3)"

echo
echo "=== can it be loaded now?"
modprobe qcom_venus 2>&1 | head -3
lsmod | grep -i venus || echo "  not loaded"
dmesg | tail -3
