#!/bin/bash
# Is the aw88166 volume fix present in our kernel, or missing?
set -uo pipefail
D=$HOME/rocknix-nf/distribution/projects/ROCKNIX
K=$HOME/rocknix-nf/port/repo

echo "=== aw88166 patches in the SM6115 series (ours)"
ls "$D/devices/SM6115/patches/linux/" | grep -i aw88 || echo "  none"

echo
echo "=== aw88166 patches in other ROCKNIX devices"
for dev in SM4450 SM8250 RK3566; do
    for p in "$D"/devices/$dev/patches/linux/*aw88166*; do
        [ -f "$p" ] || continue
        echo "  ${dev}: $(basename "$p")"
    done
done

echo
echo "=== the volume patch: subject and files"
P=$(ls "$D"/devices/SM4450/patches/linux/0034-*aw88166*make-volume* 2>/dev/null | head -1)
echo "  file: $(basename "$P")"
sed -n '1,12p' "$P" | sed 's/^/    /'
grep -E '^\+\+\+ b/' "$P" | sed 's/^/    /'

echo
echo "=== does our driver already have that fix?"
grep -n "dw_vol\|digital_volume\|aw88166_set_volume\|safe_vol" "$K/sound/soc/codecs/aw88166.c" 2>/dev/null | head -8

echo
echo "=== current driver volume control definition"
grep -n -A6 "SOC_SINGLE.*Volume\|PCM Playback Volume" "$K/sound/soc/codecs/aw88166.c" 2>/dev/null | head -20
