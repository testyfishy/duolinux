#!/bin/bash
# After enabling the VA macro's DMIC clock registers (0x84/0x88 = 0x09), does the
# microphone hear a tone? This is the loopback that has never been run since.
set -u
P=/opt/duo-stt/venv/bin/python
DUO="XDG_RUNTIME_DIR=/run/user/1000"

echo "=== VA macro DMIC clock registers before"
$P /tmp/pmem.py r 0xa4a0084 4 | sed 's/^/  /'

echo "=== re-assert enable + DIV4 on both pairs"
$P /tmp/pmem.py w 0xa4a0084 0x09 | sed 's/^/  /'
$P /tmp/pmem.py w 0xa4a0088 0x09 | sed 's/^/  /'

echo "=== tone + capture"
ffmpeg -hide_banner -loglevel error -y -f lavfi -i "sine=frequency=1000:duration=6" \
    -af volume=0.2 -ar 48000 -ac 2 /tmp/t6.wav
chmod 644 /tmp/t6.wav
su - duo -c "$DUO timeout -s INT 7 pw-record --rate 48000 --channels 1 --format s16 /tmp/va.wav" >/dev/null 2>&1 &
sleep 1
su - duo -c "$DUO timeout 5 pw-play /tmp/t6.wav" >/dev/null 2>&1
wait

echo "=== VA clock registers after"
$P /tmp/pmem.py r 0xa4a0084 4 | sed 's/^/  /'

echo
"$P" - <<'PY'
import wave, struct, math, os
p = "/tmp/va.wav"
if not os.path.exists(p):
    print("  no recording"); raise SystemExit
w = wave.open(p); n, sr = w.getnframes(), w.getframerate()
d = struct.unpack("<%dh" % n, w.readframes(n))
if n < 24000:
    print("  too short"); raise SystemExit
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
frac = goertzel(d, 1000.0, sr)/tot if tot else 0
print("  %d samples  rms=%.0f  zc/s=%.0f  1kHz=%.3f" % (len(d), rms, zc/(len(d)/sr), frac))
print("  verdict:", "MIC HEARS THE TONE" if frac > 0.12 else
      ("signal but no tone" if rms > 50 else "silent"))
PY
