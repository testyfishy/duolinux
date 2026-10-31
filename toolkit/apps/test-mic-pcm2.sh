#!/bin/sh
# Record from the capture PCM that actually opens, and measure if it hears us.
set -u
for dev in hw:0,2; do
    for rate in 48000 16000; do
        rm -f /tmp/mic-$rate.wav
        echo "=== $dev @ ${rate}Hz"
        arecord -D "$dev" -f S16_LE -r "$rate" -c 1 -d 3 /tmp/mic-$rate.wav 2>&1 | sed 's/^/    /'
        if [ -s /tmp/mic-$rate.wav ]; then
            ffmpeg -hide_banner -i /tmp/mic-$rate.wav -af volumedetect -f null - 2>&1 \
              | grep -E "mean_volume|max_volume" | sed 's/^/    /'
        else
            echo "    no file produced"
        fi
    done
done

echo
echo "=== try turning the capture path on, then record again"
amixer -c 0 sset 'ADC1 Switch' on 2>/dev/null | tail -1
amixer -c 0 sset 'DEC0 MODE' 1 2>/dev/null | tail -1
arecord -D hw:0,2 -f S16_LE -r 48000 -c 2 -d 3 /tmp/mic-stereo.wav 2>&1 | sed 's/^/    /'
[ -s /tmp/mic-stereo.wav ] && ffmpeg -hide_banner -i /tmp/mic-stereo.wav -af volumedetect -f null - 2>&1 | grep -E "mean_volume|max_volume" | sed 's/^/    /'
