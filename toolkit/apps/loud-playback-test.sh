#!/bin/bash
# Loud, explicit playback test: set BOTH the ALSA control and the PipeWire sink
# volume to maximum, play a full-scale 1 kHz tone, and report the amp registers
# while it runs.
set -u
PY=/opt/duo-stt/venv/bin/python
DUO="XDG_RUNTIME_DIR=/run/user/1000"

ffmpeg -hide_banner -loglevel error -y -f lavfi -i "sine=frequency=1000:duration=8" \
    -ar 48000 -ac 2 /tmp/loud.wav
chmod 644 /tmp/loud.wav

alsactl store -f /tmp/b.conf
"$PY" - <<'PY'
out, cur = [], None
for line in open("/tmp/b.conf"):
    s = line.strip()
    if s.startswith("name '"):
        cur = s
    if s.startswith("value ") and cur in ("name 'SPK_L PCM Playback Volume'",
                                          "name 'SPK_R PCM Playback Volume'"):
        line = "\t\tvalue 1023\n"
    out.append(line)
open("/tmp/v.conf", "w").writelines(out)
PY
alsactl restore -f /tmp/v.conf 2>/dev/null

su - duo -c "$DUO wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.0" 2>&1 | sed 's/^/  /'
echo "=== playing 8 s full-scale 1 kHz NOW"

su - duo -c "$DUO timeout 9 pw-play /tmp/loud.wav" >/tmp/play2.log 2>&1 &
sleep 3

echo "=== amp state during the tone"
for a in 0-0034 0-0035; do
    st=$(timeout 3 grep -E '^01:' /sys/kernel/debug/regmap/$a/registers | awk '{print $2}')
    vol=$(timeout 3 grep -E '^05:' /sys/kernel/debug/regmap/$a/registers | awk '{print $2}')
    echo "  $a status=0x$st aten=0x$vol"
done

wait
echo "=== player output: $(cat /tmp/play2.log | head -2)"
echo "=== control values after"
alsactl store -f /tmp/after.conf
grep -A1 "name 'SPK_L PCM Playback Volume'" /tmp/after.conf | tail -1 | sed 's/^/  /'
echo "=== sink: $(su - duo -c "$DUO wpctl get-volume @DEFAULT_AUDIO_SINK@")"
