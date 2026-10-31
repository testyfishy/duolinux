#!/bin/sh
# Clear Moonlight's client-side pairing state and restart it.
set -u
APP=com.moonlight_stream.Moonlight
HOME_APP=/home/duo

pkill -f "com.moonlight_stream.Moonlight" 2>/dev/null
sleep 2

echo "=== what exists before"
find "$HOME_APP/.var/app/$APP" -maxdepth 4 -type d 2>/dev/null | head -10
du -sh "$HOME_APP/.var/app/$APP" 2>/dev/null

# Pairing state: hosts, certificates, and the Qt caches
rm -rf "$HOME_APP/.var/app/$APP/config/Moonlight Game Streaming Project/hosts" 2>/dev/null
rm -rf "$HOME_APP/.var/app/$APP/config/Moonlight Game Streaming Project/certs" 2>/dev/null
rm -rf "$HOME_APP/.var/app/$APP/config/Moonlight Game Streaming Project/certificates" 2>/dev/null
rm -rf "$HOME_APP/.var/app/$APP/cache"/* 2>/dev/null
rm -rf "$HOME_APP/.cache/Moonlight"* 2>/dev/null

echo "=== after clearing"
find "$HOME_APP/.var/app/$APP" -maxdepth 4 -type f 2>/dev/null | head -10

chown -R duo:duo "$HOME_APP/.var/app/$APP"

echo "=== restarting"
su - duo -c "HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 \
    nohup flatpak run $APP >/tmp/moonlight-gui.log 2>&1 &"
sleep 6
echo "running: $(pgrep -fc '$APP')"
tail -4 /tmp/moonlight-gui.log 2>/dev/null
