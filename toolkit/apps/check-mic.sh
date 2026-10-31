#!/bin/sh
# Is there a usable capture device, and does it hear anything?
set -u
echo "=== capture devices"
arecord -l 2>/dev/null | sed 's/^/  /' | head -12
echo "=== pulse/pipewire sources"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 pactl list short sources' 2>/dev/null | sed 's/^/  /'

echo
echo "=== 3 s test recording"
arecord -q -f S16_LE -r 16000 -c 1 -d 3 /tmp/mictest.wav 2>/tmp/micerr.log
echo "  rc=$? file=$(stat -c %s /tmp/mictest.wav 2>/dev/null) bytes"
head -2 /tmp/micerr.log | sed 's/^/  /'

echo
echo "=== level analysis"
ffmpeg -hide_banner -i /tmp/mictest.wav -af volumedetect -f null - 2>&1 | grep -E "mean_volume|max_volume" | sed 's/^/  /'
