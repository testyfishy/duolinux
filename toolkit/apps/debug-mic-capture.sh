#!/bin/sh
# Why does capture fail? Look at the hardware capabilities and the routing setup.
set -u
echo "=== hw params for the capture PCMs"
for d in hw:0,0 hw:0,1 hw:0,2; do
    echo "--- $d"
    arecord --dump-hw-params -D "$d" -d 1 /dev/null 2>&1 | grep -E "FORMAT|RATE|CHANNELS|ACCESS|open error" | head -6 | sed 's/^/    /'
done

echo
echo "=== UCM configuration for this machine"
ls /usr/share/alsa/ucm2/conf.d/ 2>/dev/null | head -10
find /usr/share/alsa/ucm2 -iname "*retroid*" -o -iname "*sm6125*" -o -iname "*sm6115*" 2>/dev/null | head -5

echo
echo "=== card name as ALSA sees it"
cat /proc/asound/cards
echo "  card component: $(cat /proc/asound/card0/id 2>/dev/null)"

echo
echo "=== mixer controls that look like capture paths"
amixer -c 0 controls 2>/dev/null | grep -iE "capture|mic|adc|dec" | head -12 | sed 's/^/  /'

echo
echo "=== kernel messages about capture / q6asm"
dmesg | grep -iE "q6asm|q6afe|asoc|dai.*link|capture" | tail -8 | sed 's/^/  /'
