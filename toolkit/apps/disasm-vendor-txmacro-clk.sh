#!/bin/bash
# The vendor TX macro has clk_div_get() and clk_switch(), neither of which exists
# in mainline. They are 136 and 264 bytes - small enough to read directly.
set -uo pipefail
KO=/mnt/c/Users/HTPC-Aran/AppData/Local/Temp/opencode/tx_macro_dlkm.ko
OBJ=aarch64-linux-gnu-objdump

for fn in tx_macro_clk_div_get tx_macro_clk_switch; do
    echo "======== $fn"
    $OBJ -dr --disassemble="$fn" "$KO" 2>/dev/null | sed -n '/Disassembly of section .text/,$p' | head -50
    echo
done
