#!/bin/bash
# Is the AW88166 actually in the audible path? Play the same tone twice, first
# with the amp control at 0 (attenuation 1023 = silence per the mapping), then at
# 1023 (attenuation 11 = full). If both sound the same, the sound is not coming
# through the amps.
set -u
PY=/opt/duo-stt/venv/bin/python
DUO="XDG_RUNTIME_DIR=/run/user/1000"

ffmpeg -hide_banner -loglevel error -y -f lavfi -i "sine=frequency=1000:duration=3" \
    -af volume=0.3 -ar 48000 -ac 2 /tmp/ab.wav
chmod 644 /tmp/ab.wav
alsactl store -f /tmp/ab-base.conf

setvol() {
    "$PY" - "$1" <<'PY'
import sys
val = sys.argv[1]
out, cur = [], None
for line in open("/tmp/ab-base.conf"):
    s = line.strip()
    if s.startswith("name '"):
        cur = s
    if s.startswith("value ") and cur in ("name 'SPK_L PCM Playback Volume'",
                                          "name 'SPK_R PCM Playback Volume'"):
        line = "\t\tvalue %s\n" % val
    out.append(line)
open("/tmp/ab.conf", "w").writelines(out)
PY
    alsactl restore -f /tmp/ab.conf 2>/dev/null
}

echo "=== A: amp control 0 (should be SILENT) 3 s"
setvol 0
sleep 0.3
su - duo -c "$DUO timeout 4 pw-play /tmp/ab.wav" >/dev/null 2>&1
sleep 1

echo "=== B: amp control 1023 (should be LOUD) 3 s"
setvol 1023
sleep 0.3
su - duo -c "$DUO timeout 4 pw-play /tmp/ab.wav" >/dev/null 2>&1
sleep 1

echo "=== done; registers now:"
for a in 0-0034 0-0035; do printf '  %s ' $a; timeout 3 grep -E '^(01|05):' /sys/kernel/debug/regmap/$a/registers | tr '\n' ' '; echo; done
