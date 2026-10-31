#!/bin/sh
# 409 means Sunshine still holds a pairing session for this client's uniqueid.
# Regenerate the client identity so the server sees a brand new device.
set -u
APP=com.moonlight_stream.Moonlight
CFG=/home/duo/.var/app/$APP/config/Moonlight\ Game\ Streaming\ Project

pkill -f "com.moonlight_stream.Moonlight" 2>/dev/null
sleep 2

echo "=== current identity"
grep -iE "uniqueid|uuid" "$CFG/Moonlight.conf" 2>/dev/null || echo "  no uniqueid key in conf"

rm -f "$CFG/Moonlight.conf"
rm -rf /home/duo/.var/app/$APP/cache/* 2>/dev/null
chown -R duo:duo /home/duo/.var/app/$APP
echo "  conf removed; a new identity will be generated on start"

echo "=== restarting Moonlight"
su - duo -c "HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 \
    nohup flatpak run $APP >/tmp/moonlight-gui.log 2>&1 &"
sleep 8

echo "  running: $(pgrep -fc 'com.moonlight_stream.Moonlight')"
echo "  new identity: $(grep -iE 'uniqueid' "$CFG/Moonlight.conf" 2>/dev/null || echo 'not written yet')"
tail -3 /tmp/moonlight-gui.log 2>/dev/null
