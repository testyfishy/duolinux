#!/bin/bash
# Acceptance test for the two audio fixes.
#
# MIC: capture on DMIC2 and DMIC3, skipping the first 250 ms (bias ramp and
# filter settling). A working microphone gives a noise floor - hundreds of zero
# crossings per second and a non-zero RMS. An unpowered or unclocked one gives
# exact zeros, so the test also reads the codec's MIC BIAS1 enable bit while the
# stream is running: that separates "no bias" from "no clock".
#
# SPEAKERS: drive a quiet tone and step the ALSA control, reading register 05
# back from both amps. The field must be 1023 at control 0 (silence) and equal
# the profile's own attenuation (11) at control 1023, monotonically between.
set -u
PY=/opt/duo-stt/venv/bin/python
REG_L=/sys/kernel/debug/regmap/0-0035/registers
REG_R=/sys/kernel/debug/regmap/0-0034/registers

echo "=== microphone"
amixer -c0 cset "name=TX DEC0 MUX" 0 >/dev/null 2>&1
amixer -c0 cset "name=TX_AIF1_CAP Mixer DEC0" on >/dev/null 2>&1
amixer -c0 cset "name=TX_DEC0 Volume" 84 >/dev/null 2>&1

for idx in 2 3; do
    amixer -c0 cset "name=TX DMIC MUX0" "$idx" >/dev/null 2>&1
    rm -f /tmp/acc.wav
    su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 setsid timeout 3 pw-record --rate 48000 --channels 1 --format s16 /tmp/acc.wav" >/dev/null 2>&1 &
    sleep 1.2
    bias=$(for d in /sys/kernel/debug/regmap/*/registers; do
               v=$(grep -i "^3022:" "$d" 2>/dev/null | awk '{print $2}')
               [ -n "$v" ] && echo "$v" && break
           done)
    wait
    if [ -n "$bias" ]; then
        b=$((16#$bias))
        echo "  DMIC$idx: MICB1 reg=0x$bias enabled=$(( (b >> 6) & 1 )) vout=$(( b & 0x3F ))"
    else
        echo "  DMIC$idx: MICB1 register not found"
    fi
    "$PY" - "/tmp/acc.wav" "$idx" <<'PYCODE'
import sys, wave, struct, os
p, idx = sys.argv[1], sys.argv[2]
if not os.path.exists(p):
    print("  DMIC%s: no file" % idx); raise SystemExit
w = wave.open(p); n = w.getnframes(); sr = w.getframerate()
d = struct.unpack("<%dh" % n, w.readframes(n))
skip = int(0.25 * sr)
d = d[skip:]
if len(d) < 4800:
    print("  DMIC%s: too few samples (%d)" % (idx, len(d))); raise SystemExit
rms = (sum(x*x for x in d)/len(d)) ** 0.5
zc = sum(1 for k in range(1, len(d)) if (d[k-1] < 0) != (d[k] < 0))
nz = sum(1 for x in d if x)
print("  DMIC%s: rms=%.0f peak=%d zc/s=%.0f nonzero=%.1f%% -> %s"
      % (idx, rms, max(abs(x) for x in d), zc/(len(d)/sr), 100.0*nz/len(d),
         "SIGNAL" if rms > 100 else "ZEROS"))
PYCODE
done

echo
echo "=== speakers"
ffmpeg -hide_banner -loglevel error -y -f lavfi -i "sine=frequency=1000:duration=6" \
    -af "volume=0.1" -ar 48000 -ac 2 /tmp/tone-q.wav 2>/dev/null
aplay -q -D hw:0,0 -f S16_LE -r 48000 -c 2 /tmp/tone-q.wav >/dev/null 2>&1 &
tone=$!
sleep 0.6

for ctl in 0 256 512 767 1023; do
    amixer -c0 cset numid=2 "$ctl" >/dev/null 2>&1
    amixer -c0 cset numid=8 "$ctl" >/dev/null 2>&1
    sleep 0.25
    l=$(grep -iE "^05:" "$REG_L" | awk '{print $2}')
    r=$(grep -iE "^05:" "$REG_R" | awk '{print $2}')
    fl=$((16#${l:-0} & 1023)); fr=$((16#${r:-0} & 1023))
    printf '  control %4d -> atten L=%4d R=%4d\n' "$ctl" "$fl" "$fr"
done

kill "$tone" 2>/dev/null
wait 2>/dev/null

echo
echo "=== amp errors since boot"
dmesg | grep -c "aw88166" | sed 's/^/  aw88166 lines: /'
dmesg | grep -iE "aw88166.*(error|fail|over)" | tail -3 | sed 's/^/  /'
