#!/bin/sh
# Rewrite kwinrulesrc with a consistent [General] and two valid rules:
#   - keep the desktop out of the task list (existing)
#   - force Moonlight fullscreen (new)
set -u
CFG=/home/duo/.config/kwinrulesrc
[ -f "$CFG" ] && cp -p "$CFG" "/tmp/kwinrulesrc.bak.$(date +%H%M%S)"

cat > "$CFG" <<'EOF'
[General]
count=2
rules=desktop-skip-taskbar,duo-moonlight

[desktop-skip-taskbar]
Description=Keep the desktop out of the task list
types=2
typesrule=2
skiptaskbar=true
skiptaskbarrule=2

[duo-moonlight]
Description=Moonlight fullscreen on the top panel
wmclass=com.moonlight_stream.Moonlight
wmclasscomplete=false
wmclassmatch=1
types=1
fullscreen=true
fullscreenrule=2
EOF

chown duo:duo "$CFG"
echo "=== new rules file"
cat "$CFG"

echo
echo "=== reload KWin and restart Moonlight"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 qdbus6 org.kde.KWin /KWin reconfigure' 2>&1 | head -2
pkill -f "com.moonlight_stream.Moonlight" 2>/dev/null
pkill -x moonlight 2>/dev/null
sleep 2
su - duo -c "HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 \
    nohup flatpak run com.moonlight_stream.Moonlight >/tmp/moonlight-gui.log 2>&1 &"
sleep 7
echo "  instances: $(pgrep -fc moonlight)"
echo "  kwin rules loaded: $(su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 qdbus6 org.kde.KWin /KWin supportInformation' 2>/dev/null | grep -c 'duo-moonlight')"
