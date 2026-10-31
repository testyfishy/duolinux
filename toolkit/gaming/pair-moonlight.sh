#!/bin/sh
# Start a Moonlight pairing attempt and print the PIN for the Sunshine web UI.
# The host address is passed in, never stored in the repo.
set -u
HOST="${1:?usage: pair-moonlight.sh <host-ip>}"
su - duo -c "HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 QT_QPA_PLATFORM=offscreen \
    nohup flatpak run com.moonlight_stream.Moonlight pair $HOST \
    >/tmp/moonlight-pair.log 2>&1 &"
sleep 6
echo "=== pairing log"
cat /tmp/moonlight-pair.log 2>/dev/null | tail -20
echo
echo "=== PIN"
grep -oE "[0-9]{4}" /tmp/moonlight-pair.log 2>/dev/null | head -1
