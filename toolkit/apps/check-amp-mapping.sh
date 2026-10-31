#!/bin/bash
# Verify the AW88166 attenuation mapping numerically, at a safe volume.
# The control is "how far to come down from the profile default (512)":
#   0 -> 512 (-64 dB), 256 -> 256 (-32 dB), 464 -> 48 (-6 dB, the floor).
# The register is only written when playback starts, so a tone has to run.
set -u
REG=/sys/kernel/debug/regmap/0-0034/registers
read_reg() { grep -E "^05:" "$REG" 2>/dev/null | awk '{print $2}'; }

echo "  boot value:   $(read_reg)  (idle)"
echo
for v in 0 256 464; do
    amixer -c0 cset numid=2 "$v" >/dev/null 2>&1
    amixer -c0 cset numid=8 "$v" >/dev/null 2>&1
    # -64 dB for v=0, so nothing loud is heard unless v is high
    ( aplay -q -D hw:0,0 -f S16_LE -r 48000 -c 2 /tmp/tone.wav >/dev/null 2>&1 & echo $! > /tmp/tone.pid )
    sleep 0.8
    got=$(read_reg)
    kill "$(cat /tmp/tone.pid)" 2>/dev/null
    wait 2>/dev/null
    printf '  control %3d -> reg05 %s   (field %d)\n' \
        "$v" "$got" "$((16#$(echo "${got:-0}" | cut -c1-4) & 1023))"
    sleep 0.4
done

echo
echo "  restoring control 0 (quiet default)"
amixer -c0 cset numid=2 0 >/dev/null 2>&1
amixer -c0 cset numid=8 0 >/dev/null 2>&1
