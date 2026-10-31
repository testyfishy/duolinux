#!/bin/bash
# Acoustic loopback through PipeWire: play a 1 kHz tone on the speakers and
# record it with the DMIC. Proves the speaker produces sound and the microphone
# hears it, in one measurement.
#
# Volume goes through alsactl because amixer aborts on every control of this
# card (its ELEM_INFO path, not the driver).
set -u
PY=/opt/duo-stt/venv/bin/python
DUO="XDG_RUNTIME_DIR=/run/user/1000"

echo "=== tone"
ffmpeg -hide_banner -loglevel error -y -f lavfi -i "sine=frequency=1000:duration=5" \
    -af "volume=0.15" -ar 48000 -ac 2 /tmp/tone1k.wav
chmod 644 /tmp/tone1k.wav

echo "=== mic route"
amixer -c0 cset "name=TX DEC0 MUX" 0 >/dev/null 2>&1
amixer -c0 cset "name=TX_AIF1_CAP Mixer DEC0" on >/dev/null 2>&1
amixer -c0 cset "name=TX_DEC0 Volume" 84 >/dev/null 2>&1
echo "  DMIC mux: $(timeout 3 grep -m1 '^00c$' /dev/null 2>/dev/null; echo ok)"

echo "=== speaker volume -> 1023 (vendor level)"
alsactl store -f /tmp/base.conf
"$PY" - <<'PY'
out, cur = [], None
for line in open("/tmp/base.conf"):
    s = line.strip()
    if s.startswith("name '"):
        cur = s
    if s.startswith("value ") and cur in ("name 'SPK_L PCM Playback Volume'",
                                          "name 'SPK_R PCM Playback Volume'"):
        line = "\t\tvalue 1023\n"
    out.append(line)
open("/tmp/vol.conf", "w").writelines(out)
PY
alsactl restore -f /tmp/vol.conf 2>/dev/null
sleep 0.3

echo "=== record + play"
rm -f /tmp/lb.wav
su - duo -c "$DUO timeout -s INT 9 pw-record --rate 48000 --channels 1 --format s16 /tmp/lb.wav" >/tmp/rec.log 2>&1 &
sleep 2
su - duo -c "$DUO timeout 6 pw-play /tmp/tone1k.wav" >/tmp/play.log 2>&1
wait
sleep 0.5

echo "  recorder: $(stat -c %s /tmp/lb.wav 2>/dev/null || echo missing) bytes"
echo "  player:   $(cat /tmp/play.log | tail -1)"
echo "  amp during: L=$(timeout 3 grep -E '^05:' /sys/kernel/debug/regmap/0-0035/registers | awk '{print $2}')"
echo "  DMIC pair-1 clock (0xC4): $(timeout 3 grep -E '^0c4:' /sys/kernel/debug/regmap/a460000.codec-tx_macro/registers | awk '{print $2}')"
echo "  DMIC pair-0 clock (0xC0): $(timeout 3 grep -E '^0c0:' /sys/kernel/debug/regmap/a460000.codec-tx_macro/registers | awk '{print $2}')"

echo
"$PY" - <<'PY'
import wave, struct, math

w = wave.open("/tmp/lb.wav")
n, sr = w.getnframes(), w.getframerate()
d = struct.unpack("<%dh" % n, w.readframes(n))
print("  %d samples, %.2f s at %d Hz" % (n, n/sr, sr))
if n < sr:
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

whole = (sum(float(x)*x for x in d) / n) ** 0.5
print("  overall rms=%.0f peak=%d" % (whole, max(abs(x) for x in d)))

best = (0.0, 0)
for start in range(0, n - sr, sr // 2):
    seg = d[start:start+sr]
    total = sum(float(x)*x for x in seg) / len(seg)
    if total < 1.0:
        continue
    r = goertzel(seg, 1000.0, sr) / total
    if r > best[0]:
        best = (r, start)

print("  strongest 1 kHz fraction: %.3f at %.1f s" % (best[0], best[1]/sr))
print("  verdict:", "TONE HEARD - speaker and microphone both work" if best[0] > 0.2
      else ("weak tone" if best[0] > 0.03 else "no tone detected"))
PY
