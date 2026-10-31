#!/bin/bash
# Sweep the DMIC clock divider/enable parameters while a 1 kHz tone plays, and
# report which combination makes the microphone hear it.
#
# The parameters are read each time the macro's MCLK is enabled, i.e. at the
# start of every capture stream, so each trial is a fresh recording.
set -u
PY=/opt/duo-stt/venv/bin/python
DUO="XDG_RUNTIME_DIR=/run/user/1000"

PARAM=$(ls -d /sys/module/*lpass*tx*macro*/parameters 2>/dev/null | head -1)
if [ -z "$PARAM" ] || [ ! -w "$PARAM/dmic_div" ]; then
    echo "no dmic_div parameter (module not loaded with the tunables?)"; exit 1
fi
echo "parameters: $PARAM"

# mic input: DMIC2 (the handset mic in the vendor configuration)
alsactl store -f /tmp/base4.conf
"$PY" - <<'PY'
out, cur = [], None
for line in open("/tmp/base4.conf"):
    s = line.strip()
    if s.startswith("name '"):
        cur = s
    if s.startswith("value ") and cur in ("name 'TX DMIC MUX0'",):
        line = "\t\tvalue DMIC2\n"
    if s.startswith("value ") and cur in ("name 'TX DEC0 MUX'",):
        line = "\t\tvalue MSM_DMIC\n"
    if s.startswith("value ") and cur in ("name 'TX_AIF1_CAP Mixer DEC0'",):
        line = "\t\tvalue true\n"
    if s.startswith("value ") and cur in ("name 'TX_DEC0 Volume'",):
        line = "\t\tvalue 84\n"
    out.append(line)
open("/tmp/mic.conf", "w").writelines(out)
PY
alsactl restore -f /tmp/mic.conf 2>/dev/null

ffmpeg -hide_banner -loglevel error -y -f lavfi -i "sine=frequency=1000:duration=4" \
    -af "volume=0.15" -ar 48000 -ac 2 /tmp/tone1k.wav
chmod 644 /tmp/tone1k.wav

trial() {
    local div=$1 en=$2
    echo "$div" > "$PARAM/dmic_div"
    echo "$en"  > "$PARAM/dmic_en"

    rm -f /tmp/t.wav
    su - duo -c "$DUO timeout -s INT 4 pw-record --rate 48000 --channels 1 --format s16 /tmp/t.wav" >/dev/null 2>&1 &
    sleep 0.7
    su - duo -c "$DUO timeout 3 pw-play /tmp/tone1k.wav" >/dev/null 2>&1
    wait

    "$PY" - "/tmp/t.wav" "$div" "$en" <<'PY'
import sys, wave, struct, math, os
p, div, en = sys.argv[1], sys.argv[2], sys.argv[3]
if not os.path.exists(p):
    print("  div=%-2s en=%s  no recording" % (div, en)); raise SystemExit
try:
    w = wave.open(p); n, sr = w.getnframes(), w.getframerate()
    d = struct.unpack("<%dh" % n, w.readframes(n))
except Exception as e:
    print("  div=%-2s en=%s  unreadable (%s)" % (div, en, e)); raise SystemExit
if n < 24000:
    print("  div=%-2s en=%s  short" % (div, en)); raise SystemExit
d = d[sr//4:]
rms = (sum(float(x)*x for x in d)/len(d)) ** 0.5
zc = sum(1 for k in range(1, len(d)) if (d[k-1] < 0) != (d[k] < 0))
def goertzel(s, f, sr):
    k = int(0.5 + len(s)*f/sr); om = 2*math.pi*k/len(s); c = 2*math.cos(om)
    s1 = s2 = 0.0
    for x in s:
        s0 = x + c*s1 - s2; s2, s1 = s1, s0
    return (s1*s1 + s2*s2 - c*s1*s2)/(len(s)**2)
tot = sum(float(x)*x for x in d)/len(d)
frac = goertzel(d, 1000.0, sr)/tot if tot else 0.0
print("  div=%-2s en=%s  rms=%6.0f zc/s=%5.0f 1kHz=%.3f %s" %
      (div, en, rms, zc/(len(d)/sr), frac, "<== HEARS THE TONE" if frac > 0.12 else ""))
PY
    sleep 0.3
}

for combo in "0 0" "0 1" "2 0" "4 0" "4 1" "6 0" "8 0" "10 0"; do
    trial $combo
done

echo
echo "=== clock register after the sweep"
timeout 3 grep -E "^0c[04]:" /sys/kernel/debug/regmap/a460000.codec-tx_macro/registers | sed 's/^/  /'
