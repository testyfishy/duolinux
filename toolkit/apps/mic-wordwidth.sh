#!/bin/bash
# Is the DMIC stream arriving with the word width ALSA advertises?
# Captures the same input as s16 and s32 and compares high/low halves of the
# 32-bit words: a width mismatch shows up as one half being signal and the
# other being noise.
set -u
PY=/opt/duo-stt/venv/bin/python

echo "=== hw params of the capture PCM"
arecord -D hw:0,2 --dump-hw-params 2>&1 | sed -n '1,22p' | sed 's/^/  /'

echo
echo "=== route to the pinmux truth (DMIC1), gain 84"
amixer -c 0 cset "name=TX DEC0 MUX" 0 >/dev/null 2>&1
amixer -c 0 cset "name=TX DMIC MUX0" 1 >/dev/null 2>&1
amixer -c 0 cset "name=TX_AIF1_CAP Mixer DEC0" on >/dev/null 2>&1
amixer -c 0 cset "name=TX_DEC0 Volume" 84 >/dev/null 2>&1

echo
echo "=== 4 s at 48 kHz, s32 (say something if you are near the device)"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 timeout 4 pw-record --rate 48000 --channels 1 --format s32 /tmp/w32.wav' 2>&1 | head -3 | sed 's/^/  /'
echo "  mux read-back after the stream ran: $(amixer -c 0 cget 'name=TX DMIC MUX0' 2>/dev/null | grep -oE 'values=[0-9]+' | head -1)"

echo
echo "=== 2 s at 48 kHz, s16"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 timeout 2 pw-record --rate 48000 --channels 1 --format s16 /tmp/w16.wav' 2>/dev/null

echo
"$PY" - <<'PY'
import wave, struct, os

def load(path):
    w = wave.open(path)
    n, sr, ch, sw = w.getnframes(), w.getframerate(), w.getnchannels(), w.getsampwidth()
    raw = w.readframes(n)
    fmt = {1:"b", 2:"h", 4:"i"}[sw]
    d = struct.unpack("<%d%s" % (len(raw)//sw, fmt), raw)
    return d, sr, ch, sw

def stats(d):
    n = len(d)
    if not n: return "no samples"
    rms = (sum(float(x)*x for x in d)/n) ** 0.5
    zc = sum(1 for i in range(1,n) if (d[i-1] < 0) != (d[i] < 0))
    return "rms=%.0f peak=%d zc/s=%.0f" % (rms, max(abs(x) for x in d), zc)

for p in ("/tmp/w32.wav", "/tmp/w16.wav"):
    if not os.path.exists(p):
        print("%s: missing" % p); continue
    d, sr, ch, sw = load(p)
    print("%s: %d frames, %d Hz, %d ch, %d bit -> %.2f s" % (p, len(d), sr, ch, sw*8, len(d)/sr/ch))
    print("  as-is:      " + stats(d))
    if sw == 4:
        hi = [x >> 16 for x in d]
        lo = [((x & 0xFFFF) ^ 0x8000) - 0x8000 for x in d]
        print("  high 16:    " + stats(hi))
        print("  low  16:    " + stats(lo))
        print("  values are multiples of 65536: %d/%d" % (sum(1 for x in d if x % 65536 == 0), len(d)))
    print("  first 12:   %s" % (d[:12],))
PY
