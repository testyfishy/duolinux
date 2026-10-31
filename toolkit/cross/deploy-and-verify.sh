#!/bin/bash
# Deploy the cross-built wvkbd and whisper-cli, verify them, and measure the
# local whisper fallback with the same clip the on-device build used.
set -uo pipefail
KEY=$HOME/.ssh/duo_key
H=root@192.168.1.33
SSH="ssh -i $KEY -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
OUT=$HOME/builds/out

echo "=== ship"
scp -q -i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "$OUT/wvkbd-mobintl" "$OUT/whisper-cli" "$H:/tmp/" || exit 1
ls -l "$OUT/wvkbd-mobintl" "$OUT/whisper-cli"

$SSH "$H" '
set -u
echo
echo "=== identity"
file /tmp/wvkbd-mobintl /tmp/whisper-cli | sed "s/^/  /"

echo
echo "=== wvkbd: usage and the flags duo-osk relies on"
chmod 755 /tmp/wvkbd-mobintl
/tmp/wvkbd-mobintl --help 2>&1 | head -12 | sed "s/^/  /"

echo
echo "=== whisper-cli: static, no loader"
/tmp/whisper-cli --help 2>&1 | head -3 | sed "s/^/  /"

echo
echo "=== whisper-cli: speed on a real clip (tiny.en)"
M=/opt/duo-stt/models/ggml-tiny.en.bin
if [ -f "$M" ] && [ -f /tmp/mic5.wav ]; then
    ffmpeg -hide_banner -loglevel error -y -i /tmp/mic5.wav -ar 16000 -ac 1 /tmp/clip16.wav
    for i in 1 2; do
        /usr/bin/time -f "  run $i: %e s wall, %M KB" \
            /tmp/whisper-cli -m "$M" -f /tmp/clip16.wav -nt -l en 2>&1 | tail -2
    done
else
    echo "  (model or clip missing)"
fi

echo
echo "=== installing (keeping backups)"
[ -f /usr/local/bin/wvkbd-mobintl ] && cp -p /usr/local/bin/wvkbd-mobintl /usr/local/bin/wvkbd-mobintl.bak-cross
mv -f /tmp/wvkbd-mobintl /usr/local/bin/wvkbd-mobintl
chmod 755 /usr/local/bin/wvkbd-mobintl

CUR=/opt/duo-stt/whisper.cpp/build/bin/whisper-cli
if [ -f "$CUR" ]; then cp -p "$CUR" "$CUR.bak-device"; fi
mkdir -p "$(dirname "$CUR")"
mv -f /tmp/whisper-cli "$CUR"
chmod 755 "$CUR"

echo "  wvkbd:      $(ls -l /usr/local/bin/wvkbd-mobintl | awk "{print \$5}") bytes"
echo "  whisper-cli: $(ls -l $CUR | awk "{print \$5}") bytes"
echo "  running keyboard: $(pgrep -x wvkbd-mobintl >/dev/null && echo yes || echo no)"
'

echo
echo "=== amp attenuation mapping (safe volumes only)"
scp -q -i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "/mnt/c/Users/user/Documents/Default Project/duolinux/toolkit/apps/check-amp-mapping.sh" "$H:/tmp/amp.sh"
$SSH "$H" '
ffmpeg -hide_banner -loglevel error -y -f lavfi -i "sine=frequency=1000:duration=3" \
    -ar 48000 -ac 2 /tmp/tone.wav 2>/dev/null
sed -i "s/\r$//" /tmp/amp.sh
bash /tmp/amp.sh'
