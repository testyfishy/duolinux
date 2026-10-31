#!/bin/sh
# The amps are at max. Check the codec's RX digital gain feeding them, and the
# DSP-side playback volume, then try raising them.
set -u
echo "=== RX digital volumes (0 dB is the maximum, expressed as a positive index)"
for id in 44 45 46 47 48 49 50 51 52 53; do
    out=$(amixer -c 0 cget numid=$id 2>/dev/null)
    [ -n "$out" ] || continue
    name=$(echo "$out" | sed -n "s/.*name='\([^']*\)'.*/\1/p" | head -1)
    val=$(echo "$out" | grep -oE "values=[0-9]+" | head -1)
    echo "  $id $name $val"
done

echo
echo "=== all controls containing RX / Digital (with values)"
amixer -c 0 contents 2>/dev/null | awk '
/^numid=/ {id=$0} /name=/ {n=$0} /: values=/ {print id" | "n" | "$0}
' | grep -iE "RX_|digital" | head -20

echo
echo "=== q6asm / DSP volume (Mixer MultiMedia routes)"
amixer -c 0 contents 2>/dev/null | awk '
/^numid=/ {id=$0} /name=/ {n=$0} /: values=/ {print id" | "n" | "$0}
' | grep -iE "MultiMedia" | head -8
