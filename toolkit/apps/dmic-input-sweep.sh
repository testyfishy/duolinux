#!/bin/bash
# With the DMIC clock now at DIV4 (2.4 MHz), try every DMIC input while a 1 kHz
# tone plays: if the microphone is wired to a different line than DMIC2, one of
# these will hear it.
set -u
PY=/opt/duo-stt/venv/bin/python
DUO="XDG_RUNTIME_DIR=/run/user/1000"

alsactl store -f /tmp/sweep-base.conf

setmux() {
    "$PY" - "$1" <<'PY'
import sys
val = sys.argv[1]
out, cur = [], None
for line in open("/tmp/sweep-base.conf"):
    s = line.strip()
    if s.startswith("name '"):
        cur = s
    if s.startswith("value ") and cur == "name 'TX DMIC MUX0'":
        line = "\t\tvalue %s\n" % val
    out.append(line)
open("/tmp/sweep.conf", "w").writelines(out)
PY
    alsactl restore -f /tmp/sweep.conf 2>/dev/null
}

ffmpeg -hide_banner -loglevel error -y -f lavfi -i "sine=frequency=1000:duration=6" \
    -af "volume=0.15" -ar 48000 -ac 2 /tmp/tone1k.wav
chmod 644 /tmp/tone1k.wav

su - duo -c "$DUO setsid timeout 12 pw-play /tmp/tone1k.wav" >/dev/null 2>&1 &
sleep 1

for m in DMIC0 DMIC1 DMIC2 DMIC3; do
    setmux "$m"
    sleep 0.3
    rm -f "/tmp/sw-$m.wav"
    su - duo -c "$DUO timeout -s INT 3 pw-record --rate 48000 --channels 1 --format s16 /tmp/sw-$m.wav" >/dev/null 2>&1
    "$PY" - "/tmp/sw-$m.wav" "$m" <<'PY'
import sys, wave, struct, math, os
p, name = sys.argv[1], sys.argv[2]
if not os.path.exists(p):
    print("  %-6s no file" % name); raise SystemExit
try:
    w = wave.open(p)
    n, sr = w.getnframes(), w.getframerate()
    d = struct.unpack("<%dh" % n, w.readframes(n))
except Exception as e:
    print("  %-6s unreadable: %s" % (name, e)); raise SystemExit
if n < 24000:
    print("  %-6s too short" % name); raise SystemExit
d = d[sr//4:]                     # skip the first quarter second
rms = (sum(float(x)*x for x in d)/len(d)) ** 0.5
zc = sum(1 for k in range(1, len(d)) if (d[k-1] < 0) != (d[k] < 0))
def goertzel(s, f, sr):
    k = int(0.5 + len(s)*f/sr); om = 2*math.pi*k/len(s); c = 2*math.cos(om)
    s1 = s2 = 0.0
    for x in s:
        s0 = x + c*s1 - s2; s2, s1 = s1, s0
    return (s1*s1 + s2*s2 - c*s1*s2)/(len(s)**2)
tot = sum(float(x)*x for x in d)/len(d)
frac = goertzel(d, 1000.0, sr)/tot if tot else 0
print("  %-6s rms=%5.0f zc/s=%4.0f 1kHz=%.3f %s" % (name, rms, zc/(len(d)/sr), frac,
      "<== HEARS THE TONE" if frac > 0.15 else ""))
PY
done

wait
echo "=== restoring DMIC2"
setmux DMIC2
