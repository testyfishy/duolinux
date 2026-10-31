#!/bin/bash
# The vendor's DMIC clock enable indexes four .rodata tables by DMIC number.
# Dump those tables to recover the register offset, mask and value it programs.
set -uo pipefail
D=/mnt/c/Users/user/AppData/Local/Temp/opencode
KO=$D/bolero_cdc_dlkm.ko
OBJ=aarch64-linux-gnu-objdump

echo "=== .rodata table at 0x14b8 (8 x u32)"
$OBJ -s -j .rodata --start-address=0x14b8 --stop-address=0x14d8 "$KO" 2>/dev/null | tail -n +5 | sed 's/^/  /'

echo "=== .rodata table at 0x14d8 (8 x u32)"
$OBJ -s -j .rodata --start-address=0x14d8 --stop-address=0x14f8 "$KO" 2>/dev/null | tail -n +5 | sed 's/^/  /'

echo "=== .rodata table at 0x2fe8 (8 x u64 pointers)"
$OBJ -s -j .rodata --start-address=0x2fe8 --stop-address=0x3028 "$KO" 2>/dev/null | tail -n +5 | sed 's/^/  /'

echo "=== .rodata table at 0x3028 (8 x u64 pointers)"
$OBJ -s -j .rodata --start-address=0x3028 --stop-address=0x3068 "$KO" 2>/dev/null | tail -n +5 | sed 's/^/  /'

echo "=== relocations that point into those tables (they are symbol pointers)"
aarch64-linux-gnu-readelf -rW "$KO" 2>/dev/null | awk '$1 ~ /^000000000000(2fe8|2ff0|2ff8|3000|3008|3010|3018|3020|3028|3030|3038|3040|3048|3050|3058|3060)/ {print "  " $0}'

echo "=== symbols whose value is those addresses (i.e. what the pointers name)"
aarch64-linux-gnu-readelf -sW "$KO" 2>/dev/null | awk '{ if ($2 ~ /^000000000000(2fe8|2ff0|2ff8|3000|3008|3010|3018|3020|3028|3030|3038|3040|3048|3050|3058|3060)$/) print "  " $0 }'
