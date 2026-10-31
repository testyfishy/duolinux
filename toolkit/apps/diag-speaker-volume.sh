#!/bin/sh
# Where is the volume being lost? Check the codec/DSP mixer, not just the slider.
set -u
echo "=== playback mixer controls with values"
amixer -c 0 controls 2>/dev/null | grep -iE "spk|speaker|rx|hph|ear|digital volume|comp|amp" | head -25 | sed 's/^/  /'

echo
echo "=== full dump of the speaker-ish controls"
for c in "RX0 Digital Volume" "RX1 Digital Volume" "RX2 Digital Volume" "SPK" "Speaker" "EAR" "HPH"; do
    out=$(amixer -c 0 sget "$c" 2>/dev/null | grep -E "Limits|Front Left|Mono" | head -3)
    [ -n "$out" ] && { echo "  --- $c"; echo "$out" | sed 's/^/    /'; }
done

echo
echo "=== pipewire view (sinks and their volume)"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 wpctl status' 2>/dev/null | sed -n '1,25p' | sed 's/^/  /'
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 wpctl get-volume @DEFAULT_AUDIO_SINK@' 2>/dev/null | sed 's/^/  /'

echo
echo "=== ALSA cards / pcm playback devices"
aplay -l 2>/dev/null | head -8 | sed 's/^/  /'

echo
echo "=== anything limiting? (alsactl state, UCM)"
ls -l /var/lib/alsa/asound.state 2>/dev/null | sed 's/^/  /'
