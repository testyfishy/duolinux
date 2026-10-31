#!/bin/bash
# The VA macro's DMIC clock needs its core MCLK running. Mainline never powers
# the VA macro because no stream uses it, so enable that block by hand and see
# whether the microphone starts producing audio.
set -u
P=/opt/duo-stt/venv/bin/python
DUO="XDG_RUNTIME_DIR=/run/user/1000"
BASE=0xa4a0000

echo "=== VA macro low registers"
$P /tmp/pmem.py r $BASE 8 | sed 's/^/  /'

echo "=== enable VA MCLK (bit0 of 0x0000) and DMIC clocks"
$P /tmp/pmem.py w $BASE 0x01 | sed 's/^/  /'
$P /tmp/pmem.py w 0xa4a0084 0x09 | sed 's/^/  /'
$P /tmp/pmem.py w 0xa4a0088 0x09 | sed 's/^/  /'

echo
echo "=== capture with the tone"
ffmpeg -hide_banner -loglevel error -y -f lavfi -i "sine=frequency=1000:duration=6" \
    -af volume=0.2 -ar 48000 -ac 2 /tmp/t7.wav
chmod 644 /tmp/t7.wav
su - duo -c "$DUO timeout -s INT 7 pw-record --rate 48000 --channels 1 --format s16 /tmp/va2.wav" >/dev/null 2>&1 &
sleep 1
su - duo -c "$DUO timeout 5 pw-play /tmp/t7.wav" >/dev/null 2>&1
wait

echo "=== registers after"
$P /tmp/pmem.py r $BASE 4 | sed 's/^/  /'
$P /tmp/pmem.py r 0xa4a0084 2 | sed 's/^/  /'

"$P" - <<'PY'
import wave, struct, math, os
p = "/tmp/va2.wav"
if not os.path.exists(p):
    print("  no recording"); raise SystemExit
w = wave.open(p); n, sr = w.getnframes(), w.getframerate()
d = struct.unpack("<%dh" % n, w.readframes(n))
d = d[sr//4:]
rms = (sum(float(x)*x for x in d)/len(d)) ** 0.5
zc = sum(1 for k in range(1, len(d)) if (d[k-1] < 0) != (d[k] < 0))
print("  rms=%.0f zc/s=%.0f" % (rms, zc/(len(d)/sr)))
PY
