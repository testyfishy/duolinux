#!/bin/bash
# What does the vendor amp driver do for volume? List the volume/gain functions
# and the constants they reference, so the mapping can be compared with mainline.
set -uo pipefail
KO=/mnt/c/Users/user/AppData/Local/Temp/opencode/aw883xx_dlkm.ko
OBJ=aarch64-linux-gnu-objdump

echo "=== volume / gain / attenuation functions"
aarch64-linux-gnu-readelf -sW "$KO" 2>/dev/null | grep ' FUNC ' | \
    grep -iE 'volume|gain|atten|vol' | head -20 | sed 's/^/  /'

echo
echo "=== symbols mentioning dac / boost / pcm"
aarch64-linux-gnu-readelf -sW "$KO" 2>/dev/null | grep ' FUNC ' | \
    grep -iE 'dac|boost|pcm|amp|pa_' | head -20 | sed 's/^/  /'

echo
echo "=== strings that look like control names"
strings "$KO" | grep -iE 'PCM Playback Volume|Profile Set|Calib|Fade|boost|atten' | head -20 | sed 's/^/  /'
