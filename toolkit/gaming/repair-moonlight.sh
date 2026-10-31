#!/bin/sh
# Clean pairing attempt: kill any stale client, start a live one, print its PIN.
set -u
HOST="${1:?usage: reapir.sh <host>}"
pkill -f "Moonlight pair" 2>/dev/null
sleep 2
rm -f /tmp/moonlight-pair.log

su - duo -c "HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 QT_QPA_PLATFORM=offscreen \
    nohup flatpak run com.moonlight_stream.Moonlight pair $HOST \
    >/tmp/moonlight-pair.log 2>&1 &"

# wait for the PIN line
for i in $(seq 1 20); do
    sleep 1
    if grep -qiE "pin|enter" /tmp/moonlight-pair.log 2>/dev/null; then break; fi
done

echo "=== pair log (relevant)"
grep -iE "pair|pin|error|fail" /tmp/moonlight-pair.log 2>/dev/null | tail -8
echo
echo "=== PIN shown by the client"
grep -oE "[0-9]{4}" /tmp/moonlight-pair.log 2>/dev/null | tail -1
