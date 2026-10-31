#!/bin/sh
# Is the capture path at a sane gain, and start a longer recording window?
set -u
echo "=== capture gain controls"
amixer -c 0 controls 2>/dev/null | sed -n "s/.*name='\(.*\)'/\1/p" | grep -iE "ADC.*Volume|TX.*Volume|DEC.*Volume|Mic" | head -10 | while IFS= read -r c; do
    v=$(amixer -c 0 cget "name=$c" 2>/dev/null | grep -oE "values=[0-9]+" | head -1)
    l=$(amixer -c 0 cget "name=$c" 2>/dev/null | grep -oE "min=[0-9]+,max=[0-9]+" | head -1)
    echo "  $c  $v  $l"
done

echo
echo "=== current capture level (3 s, no speech expected)"
arecord -q -D hw:0,2 -f S16_LE -r 48000 -c 1 -d 3 /tmp/quiet.wav 2>/dev/null
ffmpeg -hide_banner -i /tmp/quiet.wav -af volumedetect -f null - 2>&1 | grep -E "mean_volume|max_volume" | sed 's/^/  /'

echo
echo "=== starting a 45 s capture window"
rm -f /tmp/mic-test2.wav
setsid nohup arecord -q -D hw:0,2 -f S16_LE -r 48000 -c 1 -d 45 /tmp/mic-test2.wav >/dev/null 2>&1 < /dev/null &
echo "  recording now (45 s)"
