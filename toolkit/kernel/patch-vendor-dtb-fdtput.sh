#!/bin/bash
# Add the DMIC supply route to the vendor DTB *in place* with fdtput.
#
# A dtc decompile/recompile rewrites the whole blob (phandles, symbols, fixups).
# fdtput rewrites one property and leaves the rest byte-identical, which is what
# we want on a tree that is known to boot.
set -euo pipefail
REPO="/mnt/c/Users/user/Documents/Default Project/duolinux"
SRC=$REPO/out/kernel/sm6125-retroid-pocket-duo-lite.dtb
OUT=${1:-$HOME/rocknix-nf/dtb-vendor-dmic-fdtput.dtb}

command -v fdtput >/dev/null || { echo "fdtput missing (device-tree-compiler)"; exit 1; }

cp "$SRC" "$OUT"
chmod u+w "$OUT"

echo "=== current routing"
fdtget -t s "$OUT" /sound audio-routing | tr ',' '\n' | sed 's/^/  /'

echo
echo "=== rewriting the property"
fdtput -t s "$OUT" /sound audio-routing \
    "SPK_L Speaker" "SPK_L DAC Output" \
    "SPK_R Speaker" "SPK_R DAC Output" \
    "IN1_HPHL" "HPHL_OUT" \
    "IN2_HPHR" "HPHR_OUT" \
    "AMIC2" "MIC BIAS2" \
    "TX SWR_INPUT1" "ADC2_OUTPUT" \
    "TX DMIC2" "MIC BIAS1" \
    "TX DMIC3" "MIC BIAS1"

echo
echo "=== new routing"
fdtget -t s "$OUT" /sound audio-routing | tr ',' '\n' | sed 's/^/  /'

echo
echo "=== blob integrity"
fdtget -t s "$OUT" /model 2>/dev/null | sed 's/^/  model: /'
fdtget "$OUT" /soc@0 '#address-cells' 2>/dev/null | sed 's/^/  soc address-cells: /'
ls -l "$OUT" "$SRC" | sed 's/^/  /'
echo "  differs from vendor in: $(cmp -l "$SRC" "$OUT" 2>/dev/null | wc -l) bytes"
