#!/bin/bash
# Print the audio plumbing from a vendor DTB: routing, DMIC pins, mic bias,
# VA macro and the sample-rate property. This is what mainline is missing.
set -uo pipefail
F=${1:?usage: show-vendor-audio.sh <dts>}

echo "=== audio-routing / widgets"
grep -n -A22 'qcom,audio-routing\|audio-routing =' "$F" | head -40

echo
echo "=== dmic references"
grep -n -iE 'dmic' "$F" | head -30

echo
echo "=== mic bias / supply"
grep -n -iE 'mic.bias|micbias' "$F" | head -20

echo
echo "=== va macro / voice"
grep -n -iE 'va_macro|va-macro|vamacro|VA_CODEC' "$F" | head -20

echo
echo "=== sample rate / clock properties"
grep -n -iE 'dmic-sample-rate|qcom,msm-micbias|qcom,cdc' "$F" | head -20
