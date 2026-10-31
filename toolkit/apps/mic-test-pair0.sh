#!/bin/bash
# The board DTS muxes gpio127/128 (pair 1 -> DMIC2/3) and leaves pair 0
# (gpio125/126 -> DMIC0/1) unmuxed. If the microphone is actually wired to
# pair 0, muxing those pads and selecting DMIC0/DMIC1 must produce a noise
# floor instead of digital zeros.
set -u
P=/sys/kernel/debug/pinctrl/500000.pinctrl
PY=/opt/duo-stt/venv/bin/python

amixer -c 0 cset "name=TX DEC0 MUX" 0 >/dev/null 2>&1
amixer -c 0 cset "name=TX_AIF1_CAP Mixer DEC0" on >/dev/null 2>&1
amixer -c 0 cset "name=TX_DEC0 Volume" 84 >/dev/null 2>&1

echo "$(date +%T) muxing pair 0: gpio125=dmic0_clk gpio126=dmic0_data"
echo "gpio125 dmic0_clk" > "$P/pinmux-select" 2>/dev/null || echo "  select clk failed"
echo "gpio126 dmic0_data" > "$P/pinmux-select" 2>/dev/null || echo "  select data failed"
grep -E "pin 12[56] " "$P/pinmux-pins" | sed 's/^/  /'

cap() {   # $1 = dmic index
    amixer -c 0 cset "name=TX DMIC MUX0" "$1" >/dev/null 2>&1
    rm -f "/tmp/p$1.wav"
    su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 timeout 3 pw-record --rate 48000 --channels 1 --format s16 /tmp/p$1.wav" 2>/dev/null
    "$PY" - "/tmp/p$1.wav" "$1" <<'PY'
import sys, wave, struct
p, i = sys.argv[1], sys.argv[2]
try:
    w = wave.open(p); n = w.getnframes(); sr = w.getframerate()
    d = struct.unpack("<%dh" % n, w.readframes(n))
    if n < 4800:
        print("  DMIC%s: only %d samples (device busy?)" % (i, n)); raise SystemExit
    rms = (sum(x*x for x in d)/n) ** 0.5
    zc = sum(1 for k in range(1, n) if (d[k-1] < 0) != (d[k] < 0))
    nz = sum(1 for x in d if x)
    print("  DMIC%s: %d samples, rms=%.0f, peak=%d, zc/s=%.0f, nonzero=%.1f%%"
          % (i, n, rms, max(abs(x) for x in d), zc/(n/sr), 100.0*nz/n))
except Exception as e:
    print("  DMIC%s: %s" % (i, e))
PY
}

for i in 0 1 2 3; do cap "$i"; done
cap 7

echo
echo "  restoring pair-0 pads to GPIO"
echo "gpio125 gpio" > "$P/pinmux-select" 2>/dev/null
echo "gpio126 gpio" > "$P/pinmux-select" 2>/dev/null
grep -E "pin 12[56] " "$P/pinmux-pins" | sed 's/^/  /'
amixer -c 0 cset "name=TX DMIC MUX0" 2 >/dev/null 2>&1
