#!/bin/bash
# Which digital mic input, if any, carries real audio? A working mic gives
# hundreds-plus zero crossings per second and reacts to speech.
set -u
CAP=/tmp/sweep
mkdir -p "$CAP"

echo "=== mic bias controls"
amixer -c 0 controls 2>/dev/null | grep -iE "bias" | head -8 | sed 's/^/  /'

echo
echo "=== sweep DMIC0..7 on TX DMIC MUX0"
for i in 0 1 2 3 4 5 6 7; do
    amixer -c 0 cset "name=TX DMIC MUX0" "$i" >/dev/null 2>&1
    su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 timeout 2 pw-record --rate 16000 --channels 1 --format s16 $CAP/dmic$i.wav" 2>/dev/null
    /opt/duo-stt/venv/bin/python - "$CAP/dmic$i.wav" "$i" <<'PY'
import sys, wave, struct
p, i = sys.argv[1], sys.argv[2]
try:
    w = wave.open(p); n = w.getnframes(); sr = w.getframerate()
    d = struct.unpack("<%dh" % n, w.readframes(n))
    if n < 1000:
        print(f"  DMIC{i}: no data"); raise SystemExit
    zc = sum(1 for k in range(1, len(d)) if (d[k-1] < 0) != (d[k] < 0))
    rms = (sum(x*x for x in d)/len(d)) ** 0.5
    print(f"  DMIC{i}: {n/sr:.1f}s zc/s={zc/(n/sr):6.0f} rms={rms:7.0f} peak={max(abs(x) for x in d)}")
except Exception as e:
    print(f"  DMIC{i}: {e}")
PY
done

# restore the UCM value
amixer -c 0 cset "name=TX DMIC MUX0" 3 >/dev/null 2>&1
echo "  (restored DMIC2)"
