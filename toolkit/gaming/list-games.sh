#!/bin/sh
# List the apps Sunshine exposes (needs a completed pairing).
set -u
HOST="${1:?usage: list-games.sh <host>}"
LOG=/tmp/ml-apps.log
pkill -f "com.moonlight_stream.Moonlight" 2>/dev/null
sleep 2
su - duo -c "HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 QT_QPA_PLATFORM=offscreen \
    timeout 40 flatpak run com.moonlight_stream.Moonlight list $HOST" >"$LOG" 2>&1
echo "exit: $?"
grep -viE "Qt (Info|Debug|Warning)|Executing request|Ignoring ULA|SDL" "$LOG" | head -15
echo "--- raw tail"
tail -3 "$LOG"
