#!/bin/sh
# Why are the AW88166 speaker amplifiers not controllable/loud?
set -u
echo "=== kernel messages for the speaker amps"
dmesg | grep -iE "aw881|aw88|awinic|spk|speaker|amp" | tail -15 | sed 's/^/  /'

echo
echo "=== i2c devices for the amps"
ls /sys/bus/i2c/devices/ 2>/dev/null | while read -r d; do
    n=$(cat "/sys/bus/i2c/devices/$d/name" 2>/dev/null)
    case "$n" in *aw*|*881*|*AW*) echo "  $d: $n";; esac
done

echo
echo "=== driver bound?"
for d in /sys/bus/i2c/devices/*/driver; do
    [ -e "$d" ] || continue
    echo "  $(dirname "$d" | xargs basename): $(basename "$(readlink -f "$d")")"
done | grep -iE "aw|amp" | head -5

echo
echo "=== the amp's mixer controls, read individually"
for c in "SPK_L PCM Playback Volume" "SPK_R PCM Playback Volume" "SPK_L Speaker Switch" "SPK_R Speaker Switch" "SPK_L AW88166 Profile Set"; do
    echo "--- $c"
    amixer -c 0 sget "$c" 2>&1 | head -3 | sed 's/^/    /'
done

echo
echo "=== asound.state entries for the amps"
grep -iE "aw88166|SPK_L|SPK_R" /var/lib/alsa/asound.state 2>/dev/null | head -8 | sed 's/^/  /'
