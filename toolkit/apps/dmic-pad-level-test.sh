#!/bin/bash
# Are the DMIC pads actually moving during a capture?
#
# Qualcomm TLMM keeps the input buffer live while a pin is muxed to a function,
# so /sys/kernel/debug/gpio reports the real pad level. A 2.4 MHz clock reads as
# a random mix of high and low; a stuck level means the clock never leaves the
# chip, and a stuck DATA line explains decimator output of exact zeros (the
# decimator's high-pass filter turns a constant level into 0).
set -u
P=/sys/kernel/debug/pinctrl/500000.pinctrl
DUO="XDG_RUNTIME_DIR=/run/user/1000"

echo "=== pin config"
grep -E "pin 12[78] " "$P/pinmux-pins" | sed 's/^/  /'
grep -E "pin 12[78] " "$P/pinconf-pins" | sed 's/^/  /'

echo
echo "=== gpio debugfs format"
grep -E "gpio-12[5-8]" /sys/kernel/debug/gpio | sed 's/^/  /'

echo
echo "=== capturing for 8 s, sampling the pads"
su - duo -c "$DUO timeout -s INT 8 pw-record --rate 48000 --channels 1 --format s16 /tmp/pad.wav" >/dev/null 2>&1 &
sleep 1.5

for i in $(seq 1 120); do
    grep -E "gpio-127|gpio-128" /sys/kernel/debug/gpio
done | sed 's/ *(.*|.*) */ /' > /tmp/pads.txt

echo "  --- gpio127 (clock)"
grep "gpio-127" /tmp/pads.txt | awk '{print $NF}' | sort | uniq -c | sed 's/^/    /'
echo "  --- gpio128 (data)"
grep "gpio-128" /tmp/pads.txt | awk '{print $NF}' | sort | uniq -c | sed 's/^/    /'

wait

echo
echo "=== clock register during/after"
timeout 3 grep -E "^0c[04]:" /sys/kernel/debug/regmap/a460000.codec-tx_macro/registers | sed 's/^/  /'
echo "  divider=$(cat /sys/module/snd_soc_lpass_tx_macro/parameters/dmic_div 2>/dev/null) enable=$(cat /sys/module/snd_soc_lpass_tx_macro/parameters/dmic_en 2>/dev/null)"
