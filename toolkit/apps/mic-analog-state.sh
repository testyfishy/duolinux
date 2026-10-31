#!/bin/bash
# Is there an analog microphone on the WCD9370 (AMIC1/AMIC2 + MIC BIAS)?
# Lists the controls the capture path needs and the codec DAPM widget state.
set -u
echo "=== capture-side mixer controls"
amixer -c 0 controls 2>/dev/null | sed -n "s/.*name='\(.*\)'/\1/p" | grep -iE "ADC|SMIC|HDR|MIC|DEC|TX" | sort -u | head -40

echo
echo "=== DAPM dirs"
ls -d /sys/kernel/debug/asoc/*/dapm 2>/dev/null

echo
echo "=== analog mic widgets"
for w in AMIC1 AMIC2 AMIC3 "MIC BIAS1" "MIC BIAS2" ADC1 ADC2 ADC3; do
    f=$(ls /sys/kernel/debug/asoc/*/dapm/"$w" 2>/dev/null | head -1)
    if [ -n "$f" ]; then
        echo "  $w: $(grep -m1 -oE 'On|Off' "$f")"
    else
        echo "  $w: (no such widget)"
    fi
done

echo
echo "=== all widgets containing MIC/ADC/DEC (state)"
for f in /sys/kernel/debug/asoc/*/dapm/*; do
    b=$(basename "$f")
    case "$b" in
        *MIC*|*ADC*|*DEC*|*DMIC*) echo "  $b: $(grep -m1 -oE 'On|Off' "$f")";;
    esac
done | head -40
