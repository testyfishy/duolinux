#!/bin/sh
# Video plays but no sound. Where does the audio stop?
set -u
echo "=== is PipeWire receiving a stream?"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 wpctl status' 2>/dev/null | sed -n '/Audio/,/Video/p' | head -20 | sed 's/^/  /'
echo "  sink volume: $(su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 wpctl get-volume @DEFAULT_AUDIO_SINK@' 2>/dev/null)"
echo "  muted?:      $(su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 wpctl get-volume @DEFAULT_AUDIO_SINK@' 2>/dev/null | grep -c MUTED)"

echo
echo "=== clients with a playback stream"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 pactl list short sink-inputs' 2>/dev/null | sed 's/^/  /' || echo "  (pactl unavailable)"

echo
echo "=== mixer state during playback"
for n in "SPK_L Speaker Switch" "SPK_R Speaker Switch"; do
    printf '  %-24s %s\n' "$n" "$(amixer -c 0 sget "$n" 2>/dev/null | grep -oE 'values=[a-z]+' | head -1)"
done
echo "  MI2S route: $(amixer -c 0 sget 'PRI_MI2S_RX Audio Mixer MultiMedia1' 2>/dev/null | grep -oE 'values=[a-z]+' | head -1)"

echo
echo "=== amp registers during playback (05 = volume, 01 = status)"
for a in 0-0034 0-0035; do
    f=/sys/kernel/debug/regmap/$a/registers
    [ -r "$f" ] || continue
    echo "  $a: $(grep -E '^01:|^05:' "$f" 2>/dev/null | tr '\n' ' ')"
done

echo
echo "=== recent amp messages"
dmesg | grep -i aw88166 | tail -3 | sed 's/^/  /'

echo
echo "=== is any process holding the playback PCM?"
grep -l "Multimedia\|pcmC0D0p" /proc/*/maps 2>/dev/null | head -3 | sed 's/^/  /'
