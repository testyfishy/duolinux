#!/bin/sh
# Is the host usable at all? `list` fails cleanly if pairing never completed.
set -u
HOST="${1:?usage: try-moonlight-list.sh <host>}"
LOG=/tmp/ml-list.log
pkill -f "com.moonlight_stream.Moonlight" 2>/dev/null
sleep 2
su - duo -c "HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 QT_QPA_PLATFORM=offscreen \
    timeout 30 flatpak run com.moonlight_stream.Moonlight list $HOST" >"$LOG" 2>&1
rc=$?
echo "=== exit: $rc"
grep -vE "Executing request|Qt Debug|Ignoring ULA" "$LOG" | tail -15
echo
echo "=== pairing state in conf"
grep -oE "[0-9]\\\\hostname=[^ ]*|[0-9]\\\\srvcert=@ByteArray\(\)" \
    "/home/duo/.var/app/com.moonlight_stream.Moonlight/config/Moonlight Game Streaming Project/Moonlight.conf" 2>/dev/null
