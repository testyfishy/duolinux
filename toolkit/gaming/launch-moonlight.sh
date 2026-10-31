#!/bin/sh
# Restart Moonlight GUI cleanly and confirm it is running.
set -u
APP=com.moonlight_stream.Moonlight
pkill -f "$APP" 2>/dev/null
pkill -x moonlight 2>/dev/null
sleep 2
: > /tmp/moonlight-gui.log
su - duo -c "HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 \
    nohup flatpak run $APP >/tmp/moonlight-gui.log 2>&1 &"
sleep 7
echo "instances: $(pgrep -fc moonlight)"
echo "identity: $(grep -i '^uniqueid' "/home/duo/.var/app/$APP/config/Moonlight Game Streaming Project/Moonlight.conf" 2>/dev/null || echo none)"
tail -3 /tmp/moonlight-gui.log 2>/dev/null
