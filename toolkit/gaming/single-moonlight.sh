#!/bin/sh
# Kill every Moonlight instance and start exactly one for a deliberate pairing.
set -u
APP=com.moonlight_stream.Moonlight
echo "=== instances before: $(pgrep -fc moonlight)"
pkill -f "com.moonlight_stream.Moonlight" 2>/dev/null
pkill -x moonlight 2>/dev/null
sleep 3
echo "  after kill: $(pgrep -fc moonlight)"

: > /tmp/moonlight-gui.log
su - duo -c "HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 \
    nohup flatpak run $APP >/tmp/moonlight-gui.log 2>&1 &"
sleep 6

echo "=== instances now: $(pgrep -fc moonlight)"
ps -eo pid,etime,comm | grep -i moonlight | head -3
echo "=== identity: $(grep -i '^uniqueid' "/home/duo/.var/app/$APP/config/Moonlight Game Streaming Project/Moonlight.conf" 2>/dev/null || echo none)"
echo "=== log"
tail -3 /tmp/moonlight-gui.log
