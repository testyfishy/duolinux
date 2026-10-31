#!/bin/bash
# Retry the analog (WCD9370) capture route with the correct items:
# ADC2 MUX=INP2 (item 0), TX SMIC MUX0=SWR_MIC1 (item 2). The first attempt
# selected INP3 and the stream collapsed to 0.15 s.
set -u
PY=/opt/duo-stt/venv/bin/python

for n in "DEC0 MODE" "ADC2 Volume" "TX_DEC0 Volume" "TX_AIF1_CAP Mixer DEC0"; do
    printf '  %-28s ' "$n"
    amixer -c 0 cget "name=$n" 2>&1 | grep -E "^  ; (type|Item|values)" | tr '\n' ' ' | sed 's/  ; //g'
    echo
done

sw() { amixer -c 0 cset "name=$1" "$2" >/dev/null 2>&1 && echo "  $1 = $2" || echo "  $1 = $2  FAILED"; }
echo "=== applying"
sw "TX DEC0 MUX" 1
sw "TX SMIC MUX0" 2
sw "ADC2 MUX" 0
sw "ADC2_MIXER Switch" on
sw "ADC2 Switch" on
sw "ADC2 Volume" 20
sw "TX_AIF1_CAP Mixer DEC0" on
sw "TX_DEC0 Volume" 84
sw "MultiMedia3 Mixer TX_CODEC_DMA_TX_3" on

sleep 1
echo
echo "=== 8 s capture"
rm -f /tmp/an2.wav
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 timeout 8 pw-record --rate 48000 --channels 1 --format s16 /tmp/an2.wav' 2>&1 | head -3 | sed 's/^/  /'

"$PY" - <<'PY'
import wave, struct, os
p = "/tmp/an2.wav"
if not os.path.exists(p):
    print("  no file"); raise SystemExit
w = wave.open(p); n = w.getnframes(); sr = w.getframerate()
d = struct.unpack("<%dh" % n, w.readframes(n))
rms = (sum(x*x for x in d)/max(1,n)) ** 0.5
zc = sum(1 for k in range(1, n) if (d[k-1] < 0) != (d[k] < 0))
nz = sum(1 for x in d if x)
print("  %.2f s, rms=%.0f, peak=%d, zc/s=%.0f, nonzero=%.1f%%" % (n/sr, rms, max(abs(x) for x in d) if n else 0, (zc/(n/sr) if n else 0), (100.0*nz/n if n else 0)))
PY
