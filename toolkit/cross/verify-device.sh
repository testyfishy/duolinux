#!/bin/bash
# Confirm the cross-built binaries run on the handheld and measure the local
# whisper fallback, which used to be built on the device.
set -uo pipefail
KEY=$HOME/.ssh/duo_key
H=root@192.168.1.33
SSH="ssh -i $KEY -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"

$SSH "$H" '
echo "=== whisper-cli"
CUR=/opt/duo-stt/whisper.cpp/build/bin/whisper-cli
ls -l "$CUR" | sed "s/^/  /"
ffmpeg -hide_banner -loglevel error -y -f lavfi -i "sine=frequency=440:duration=3" \
    -ar 16000 -ac 1 /tmp/t16.wav 2>/dev/null
for i in 1 2 3; do
    s=$(date +%s%N)
    "$CUR" -m /opt/duo-stt/models/ggml-tiny.en.bin -f /tmp/t16.wav -nt -l en >/dev/null 2>&1
    e=$(date +%s%N)
    echo "  run $i: $(( (e - s) / 1000000 )) ms"
done

echo
echo "=== wvkbd"
/usr/local/bin/wvkbd-mobintl --help 2>&1 | head -1 | sed "s/^/  /"
echo "  running: $(pgrep -x wvkbd-mobintl >/dev/null && echo yes || echo no)"

echo
echo "=== binaries"
ls -l /usr/local/bin/wvkbd-mobintl /usr/local/bin/wvkbd-mobintl.bak-cross \
      /opt/duo-stt/whisper.cpp/build/bin/whisper-cli* 2>/dev/null | sed "s/^/  /"
'
