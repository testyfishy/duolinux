#!/bin/bash
# Run the amp's own calibration, which Android performs and we never have.
# The vendor driver exposes re25/f0/f0_q calibration; mainline exposes the
# "Calib" control, which is currently 0 (never run).
set -u
PY=/opt/duo-stt/venv/bin/python
DUO="XDG_RUNTIME_DIR=/run/user/1000"

alsactl store -f /tmp/cal-base.conf

echo "=== current calib values"
grep -A1 -E "name .SPK_[LR] (Calib|AW88166 Profile Set)" /tmp/cal-base.conf | \
    grep -E "name|value" | paste - - | sed 's/^/  /'

"$PY" - <<'PY'
out, cur = [], None
for line in open("/tmp/cal-base.conf"):
    s = line.strip()
    if s.startswith("name '"):
        cur = s
    if s.startswith("value ") and cur in ("name 'SPK_L Calib'", "name 'SPK_R Calib'"):
        line = "\t\tvalue 1\n"
    out.append(line)
open("/tmp/cal.conf", "w").writelines(out)
PY

echo
echo "=== triggering calibration (Calib=1)"
alsactl restore -f /tmp/cal.conf 2>&1 | head -2
sleep 3

echo "=== dmesg from calibration"
dmesg | tail -8 | sed 's/^/  /'

echo
echo "=== playing a test tone at max volume"
alsactl store -f /tmp/cal-after.conf
grep -A1 -E "name .SPK_[LR] Calib" /tmp/cal-after.conf | grep -E "value" | sed 's/^/  /'
ffmpeg -hide_banner -loglevel error -y -f lavfi -i "sine=frequency=1000:duration=5" \
    -ar 48000 -ac 2 /tmp/cal-tone.wav
chmod 644 /tmp/cal-tone.wav
su - duo -c "$DUO timeout 6 pw-play /tmp/cal-tone.wav" >/dev/null 2>&1
echo "  (tone done)"
