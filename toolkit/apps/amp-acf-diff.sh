#!/bin/bash
# Capture the live amp register dump during playback and diff it against the ACF
# profile, to find registers the driver did not apply.
set -u
KEY=$HOME/.ssh/duo_key
H=root@192.168.1.33
SSH="ssh -i $KEY -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
REPO="/mnt/c/Users/user/Documents/Default Project/duolinux"

$SSH "$H" '
ffmpeg -hide_banner -loglevel error -y -f lavfi -i "sine=frequency=1000:duration=6" -ar 48000 -ac 2 /tmp/t8.wav
chmod 644 /tmp/t8.wav
su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 timeout 7 pw-play /tmp/t8.wav" >/dev/null 2>&1 &
sleep 2
cat /sys/kernel/debug/regmap/0-0034/registers
wait
' > /tmp/amp-live.txt

echo "captured $(grep -c ':' /tmp/amp-live.txt) register lines"
python3 "$REPO/toolkit/apps/diff-acf-vs-live.py" "$HOME/android-images/aw883xx_acf.bin" /tmp/amp-live.txt
