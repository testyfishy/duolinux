#!/bin/sh
# Fit Moonlight's window to the top panel's LOGICAL size and confirm that the
# "no hardware decoder" warning is a probe result, not a dead end.
set -u
APP=com.moonlight_stream.Moonlight
CFG="/home/duo/.var/app/$APP/config/Moonlight Game Streaming Project/Moonlight.conf"

pkill -f "com.moonlight_stream.Moonlight" 2>/dev/null
pkill -x moonlight 2>/dev/null
sleep 2

echo "=== current window settings"
grep -iE "window|size|resolution|display|screen" "$CFG" 2>/dev/null | head -20

# The two panels are one desktop: DSI-1 is 1098x618 logical, DP-1 is 1098x823.
# A 1280x720 default cannot fit either.
if grep -qiE '^windowSize=' "$CFG"; then
    sed -i 's/^windowSize=.*/windowSize=1024x576/' "$CFG"
elif grep -q '^\[General\]' "$CFG"; then
    sed -i '/^\[General\]/a windowSize=1024x576' "$CFG"
else
    printf '[General]\nwindowSize=1024x576\n' >> "$CFG"
fi

# Force the software decoder so Moonlight stops probing for hardware it lacks.
if grep -qiE '^decoder=' "$CFG"; then
    sed -i 's/^decoder=.*/decoder=software/' "$CFG"
else
    sed -i '/^\[General\]/a decoder=software' "$CFG"
fi

chown duo:duo "$CFG"
echo
echo "=== after"
grep -iE "^windowSize=|^decoder=" "$CFG"

echo
echo "=== restart"
su - duo -c "HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 \
    nohup flatpak run $APP >/tmp/moonlight-gui.log 2>&1 &"
sleep 6
echo "  instances: $(pgrep -fc moonlight)"
echo "  log:"; tail -4 /tmp/moonlight-gui.log
