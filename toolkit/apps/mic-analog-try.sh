#!/bin/bash
# The board wires AMIC2 <- MIC BIAS2 and TX SWR_INPUT1 <- ADC2_OUTPUT, i.e. an
# analog microphone into the WCD9370. Point DEC0 at SWR_MIC and read ADC2,
# then measure. Digital zero here means nothing is attached; a noise floor that
# reacts to sound means the analog mic works.
set -u
PY=/opt/duo-stt/venv/bin/python

echo "=== relevant controls and their items"
for n in "ADC2 MUX" "TX DEC0 MUX" "TX SMIC MUX0" "MultiMedia3 Mixer TX_CODEC_DMA_TX_3"; do
    printf '  %-38s ' "$n"
    amixer -c 0 cget "name=$n" 2>&1 | grep -E "^  ; (type|Item|values)" | tr '\n' ' ' | sed 's/  ; //g'
    echo
done

echo
echo "=== applying the analog capture route"
sw() { amixer -c 0 cset "name=$1" "$2" >/dev/null 2>&1 && echo "  $1 = $2" || echo "  $1 = $2  FAILED"; }
sw "TX DEC0 MUX" 1
sw "ADC2 MUX" 1
sw "ADC2_MIXER Switch" on
sw "ADC2 Switch" on
sw "ADC2 Volume" 18
sw "TX_AIF1_CAP Mixer DEC0" on
sw "TX_DEC0 Volume" 84
sw "MultiMedia3 Mixer TX_CODEC_DMA_TX_3" on

echo
echo "=== 6 s capture (plug a TRRS headset, or speak near the device)"
rm -f /tmp/an.wav
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 timeout 6 pw-record --rate 48000 --channels 1 --format s16 /tmp/an.wav' 2>/dev/null

"$PY" - <<'PY'
import wave, struct, os
p = "/tmp/an.wav"
if not os.path.exists(p):
    print("  no file"); raise SystemExit
w = wave.open(p); n = w.getnframes(); sr = w.getframerate()
d = struct.unpack("<%dh" % n, w.readframes(n))
rms = (sum(x*x for x in d)/n) ** 0.5
zc = sum(1 for k in range(1, n) if (d[k-1] < 0) != (d[k] < 0))
nz = sum(1 for x in d if x)
print("  %.2f s, rms=%.0f, peak=%d, zc/s=%.0f, nonzero=%.1f%%" % (n/sr, rms, max(abs(x) for x in d), zc/(n/sr), 100.0*nz/n))
print("  first 12: %s" % (d[:12],))
PY

echo
echo "=== transcript"
curl -s -m 60 -F "file=@/tmp/an.wav" -F "model=whisper-1" -F "response_format=text" http://100.97.144.91:8090/v1/audio/transcriptions 2>&1 | head -c 300
echo
