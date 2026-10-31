#!/bin/bash
# Does the vendor module keep its symbol table? That decides whether the DMIC
# clock code can be found by name or has to be hunted by cross-reference.
set -uo pipefail
D=/mnt/c/Users/HTPC-Aran/AppData/Local/Temp/opencode
for f in tx_macro_dlkm.ko bolero_cdc_dlkm.ko; do
    echo "=== $f"
    ls -l "$D/$f" | awk '{print "  size:", $5}'
    aarch64-linux-gnu-readelf -h "$D/$f" 2>/dev/null | grep -E "Type:|Machine:"
    funcs=$(aarch64-linux-gnu-readelf -sW "$D/$f" 2>/dev/null | grep -c ' FUNC ')
    echo "  function symbols: $funcs"
    aarch64-linux-gnu-readelf -sW "$D/$f" 2>/dev/null | grep ' FUNC ' | \
        grep -iE 'dmic|mclk|enable|clock|dec' | head -12 | sed 's/^/    /'
    echo "  strings mentioning dmic:"
    strings "$D/$f" | grep -iE 'dmic|tx_macro' | head -8 | sed 's/^/    /'
done
