#!/bin/bash
# Who drives the DMIC pins and who clocks them, according to the vendor tree?
set -uo pipefail
F=$HOME/android-images/dtbo_a/dtb-07.dts

echo "=== cdc_dmic23_pinctrl node"
grep -n -A16 'cdc_dmic23_pinctrl {' "$F" | head -22

echo
echo "=== va-macro node"
grep -n -A18 'va-macro@0a4a0000 {' "$F" | head -26

echo
echo "=== whoever owns phandle 0x8a (referenced as qcom,cdc-dmic23-gpios)"
grep -n -B8 'phandle = <0x8a>' "$F" | head -20

echo
echo "=== dmic sample rate properties"
grep -n -B3 'dmic-sample-rate' "$F" | head -20

echo
echo "=== msm-cdc-pinctrl nodes"
grep -n 'msm-cdc-pinctrl\|cdc_pinctrl\|cdc-pinctrl' "$F" | head -12
