#!/bin/bash
# Speaker ladder and acoustic loopback, driven through alsactl.
#
# amixer cannot read or write any control on this card (its ELEM_INFO path
# aborts, rc 134, for every numid), but alsactl works because it uses ELEM_READ.
# So the state file is the control interface here.
#
# 1. Play a long tone and step the volume control 0 -> 512 -> 1023 while the amp
#    is running, reading attenuation register 05 each time.
# 2. Leave it at 1023 and record the tone with the microphone (raw PCM, so a
#    killed recorder still leaves usable data).
set -u
PY=/opt/duo-stt/venv/bin/python
DUO="XDG_RUNTIME_DIR=/run/user/1000"

echo "=== baseline state"
alsactl store -f /tmp/base.conf
grep -A1 "name 'SPK_L PCM Playback Volume'" /tmp/base.conf | tail -1 | sed 's/^/  /'

setvol() {
    "$PY" - "$1" <<'PY'
import sys
val = sys.argv[1]
out = []
cur = None
for line in open("/tmp/base.conf"):
    s = line.strip()
    if s.startswith("name '"):
        cur = s
    if s.startswith("value ") and cur in ("name 'SPK_L PCM Playback Volume'",
                                          "name 'SPK_R PCM Playback Volume'"):
        line = "\t\tvalue %s\n" % val
    out.append(line)
open("/tmp/step.conf", "w").writelines(out)
PY
    alsactl restore -f /tmp/step.conf 2>/dev/null
}

echo
echo "=== ladder while a tone plays"
su - duo -c "$DUO timeout 12 pw-play /tmp/tone1k.wav" >/dev/null 2>&1 &
sleep 1.5
for v in 0 256 512 767 1023; do
    setvol "$v"
    sleep 0.7
    l=$(timeout 3 grep -E '^05:' /sys/kernel/debug/regmap/0-0035/registers | awk '{print $2}')
    r=$(timeout 3 grep -E '^05:' /sys/kernel/debug/regmap/0-0034/registers | awk '{print $2}')
    printf '  control %4d -> atten L=%4d R=%4d  (raw %s %s)\n' "$v" \
        "$((16#${l:-0} & 1023))" "$((16#${r:-0} & 1023))" "$l" "$r"
done
wait

echo
echo "=== loopback: same tone recorded by the microphone at control 1023"
setvol 1023
sleep 0.5
amixer -c0 cset "name=TX DEC0 MUX" 0 >/dev/null 2>&1
rm -f /tmp/lb.raw
su - duo -c "$DUO setsid timeout 9 pw-record --raw --rate 48000 --channels 1 --format s16 /tmp/lb.raw" >/dev/null 2>&1 &
sleep 1.5
su - duo -c "$DUO timeout 6 pw-play /tmp/tone1k.wav" >/dev/null 2>&1
sleep 1
pkill -f "pw-record --raw" 2>/dev/null
sleep 0.5

"$PY" - <<'PY'
import struct, os, math

p = "/tmp/lb.raw"
if not os.path.exists(p):
    print("  no recording"); raise SystemExit
raw = open(p, "rb").read()
d = struct.unpack("<%dh" % (len(raw)//2), raw)
print("  %d samples (%.2f s at 48 kHz)" % (len(d), len(d)/48000))
if len(d) < 48000:
    print("  too short"); raise SystemExit

def goertzel(samples, freq, sr):
    k = int(0.5 + len(samples) * freq / sr)
    omega = 2.0 * math.pi * k / len(samples)
    coeff = 2.0 * math.cos(omega)
    s1 = s2 = 0.0
    for x in samples:
        s0 = x + coeff * s1 - s2
        s2, s1 = s1, s0
    return (s1*s1 + s2*s2 - coeff*s1*s2) / (len(samples) ** 2)

# scan 1 s windows for the window with the most 1 kHz energy
best = (0.0, 0)
for start in range(0, len(d) - 48000, 24000):
    w = d[start:start+48000]
    total = sum(float(x)*x for x in w) / len(w)
    if total < 1.0:
        continue
    r = goertzel(w, 1000.0, 48000) / total
    if r > best[0]:
        best = (r, start)
print("  best 1 kHz fraction: %.3f in the window at %.2f s" % (best[0], best[1]/48000))
print("  rms of the loudest window: %.0f" % ((sum(float(x)*x for x in d[best[1]:best[1]+48000])/48000) ** 0.5))
print("  verdict:", "TONE HEARD - speaker and microphone both work" if best[0] > 0.2
      else ("weak tone" if best[0] > 0.03 else "no tone detected"))
PY
