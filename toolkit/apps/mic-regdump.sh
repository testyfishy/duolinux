#!/bin/bash
# Corrected register-level check of the DMIC path while capture is streaming:
# debugfs prints 3-digit hex addresses and 8-digit values.
set -u
REG=/sys/kernel/debug/regmap/a460000.codec-tx_macro/registers

amixer -c 0 cset "name=TX DEC0 MUX" 0 >/dev/null 2>&1
amixer -c 0 cset "name=TX DMIC MUX0" 2 >/dev/null 2>&1
amixer -c 0 cset "name=TX_AIF1_CAP Mixer DEC0" on >/dev/null 2>&1
amixer -c 0 cset "name=TX_DEC0 Volume" 84 >/dev/null 2>&1

rm -f /tmp/reg.wav
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 setsid timeout 10 pw-record --rate 48000 --channels 1 --format s16 /tmp/reg.wav' >/dev/null 2>&1 &
sleep 3

reg() { printf '  0x%04x = %s\n' "$1" "$(grep -i "^$(printf '%03x:' $1)" "$REG" 2>/dev/null | awk '{print $2}')"; }

echo "=== MCLK / DMIC clock control"
for a in 0x0000 0x0004 0x0090; do reg $((a)); done
echo "=== CDC_TX_TOP_CSR_SWR_DMICn_CTL (n=0..7)"
for n in 0 1 2 3 4 5 6 7; do reg $((0x00C0 + n*4)); done
echo "=== DEC0 input mux (ADC_MUX0_CFG0/1) and DEC0 path"
for a in 0x0100 0x0104 0x0108 0x010c 0x0400 0x0404 0x0408 0x040c; do reg $((a)); done

echo
echo "=== powered widgets relating to the capture path"
d=$(ls -d /sys/kernel/debug/asoc/*/dapm 2>/dev/null | head -1)
for f in "$d"/*; do
    head -1 "$f" 2>/dev/null | grep -q ': On' && basename "$f"
done | grep -iE "dmic|dec|tx_aif|tx_mclk|tx_core" | head -30

wait
echo
echo "=== capture level"
ffmpeg -hide_banner -i /tmp/reg.wav -af volumedetect -f null - 2>&1 | grep -E "mean_volume|max_volume" | sed 's/^/  /'
