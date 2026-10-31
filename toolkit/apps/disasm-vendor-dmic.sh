#!/bin/bash
# Disassemble the vendor's DMIC clock enable and its callers, with relocations,
# so the exact helper calls and immediate values are visible.
set -uo pipefail
D=/mnt/c/Users/HTPC-Aran/AppData/Local/Temp/opencode
OBJ=aarch64-linux-gnu-objdump

for fn in bolero_dmic_clk_enable bolero_tx_mclk_enable; do
    echo "=== $fn"
    $OBJ -dr --disassemble="$fn" "$D/bolero_cdc_dlkm.ko" 2>/dev/null | head -60
    echo
done
