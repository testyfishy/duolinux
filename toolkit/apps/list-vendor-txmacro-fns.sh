#!/bin/bash
# Find how the vendor's TX macro driver enables and clocks the DMIC, from its
# own module (which keeps symbols). Android on this device captures through the
# TX macro, so this is the exact sequence mainline is missing.
set -uo pipefail
KO=/mnt/c/Users/user/AppData/Local/Temp/opencode/tx_macro_dlkm.ko

echo "=== DMIC-related functions"
aarch64-linux-gnu-readelf -sW "$KO" 2>/dev/null | grep ' FUNC ' | \
    grep -iE 'dmic|dec_rx|wakeup|clk' | sed 's/^/  /' | head -20

echo
echo "=== all function symbols (names only, first 60)"
aarch64-linux-gnu-readelf -sW "$KO" 2>/dev/null | grep ' FUNC ' | \
    awk '{print $8}' | grep -v '^$' | sort -u | head -60 | tr '\n' ' '
echo
