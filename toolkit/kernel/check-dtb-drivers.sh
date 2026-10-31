#!/bin/bash
# Every compatible string in the board DTB must have a driver in the new kernel,
# otherwise that node silently fails to probe (black panel, dead bridge).
set -uo pipefail
W=$HOME/rocknix-nf
T=/tmp/dtb-check
M=$W/stage-7.2.11/lib/modules/7.2.11-nf

grep -oE 'compatible = "[^"]+"' "$T/board.dts" | sed 's/compatible = //; s/"//g' | sort -u > "$T/dtb-compat.txt"
grep -oE 'compatible = "[^"]+", "[^"]+"' "$T/board.dts" | sed 's/compatible = //; s/"//g; s/, /|/g' > /dev/null 2>&1 || true

gzip -dc "$W/KERNEL-7.2.11-nf" > "$T/Image" 2>/dev/null
strings "$T/Image" > "$T/img.str"

echo "compatibles in dtb: $(wc -l < "$T/dtb-compat.txt")"
missing=0
while IFS= read -r c; do
    if grep -qxF "$c" "$T/img.str" || grep -qF "$c" "$M/modules.alias"; then :; else
        echo "  NO DRIVER: $c"; missing=$((missing+1))
    fi
done < "$T/dtb-compat.txt"
echo "compatibles with no driver in the new kernel: $missing"

echo
echo "=== the display chain specifically"
for c in himax,hx83112a qcom,sm6125-dp qcom,sm6125-dpu wl818s; do
    img=$(grep -cxF "$c" "$T/img.str" || true)
    mod=$(grep -cF "$c" "$M/modules.alias" || true)
    printf "  %-22s image=%s alias=%s\n" "$c" "$img" "$mod"
done

echo
echo "=== which module provides the panel/bridge?"
grep -E "himax|wl818s" "$M/modules.alias" | head -4
