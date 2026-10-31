#!/bin/bash
# Read the vendor's volume conversion and setter, to derive the control -> dB ->
# register mapping it uses. Mainline just writes the control value into the
# attenuation field, which may not be the same thing at all.
set -uo pipefail
KO=/mnt/c/Users/HTPC-Aran/AppData/Local/Temp/opencode/aw883xx_dlkm.ko
OBJ=aarch64-linux-gnu-objdump

for fn in aw883xx_dev_vol_reg_val_to_db aw883xx_dev_vol_db_val_to_reg aw_dev_set_volume aw883xx_volume_info; do
    echo "======== $fn"
    $OBJ -dr --disassemble="$fn" "$KO" 2>/dev/null | sed -n '/Disassembly of section/,$p' | head -45
    echo
done
