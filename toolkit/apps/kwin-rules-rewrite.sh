#!/bin/bash
# Rewrite kwinrulesrc cleanly. Every resizable window type is maximised, so no
# window can open partially outside the desktop.
#
# Window type bits: Normal=1, Utility=32, Dialog=128 -> 161.
# Menus, tooltips, notifications and the desktop are deliberately excluded.
set -u
CFG=/home/duo/.config/kwinrulesrc
[ -f "$CFG" ] && cp -p "$CFG" "/tmp/kwinrulesrc.bak.$(date +%H%M%S)"

cat > "$CFG" <<'EOF'
[General]
count=4
rules=duo-maximize-all,desktop-skip-taskbar,duo-moonlight,duo-tsukimi-player

[duo-maximize-all]
Description=Maximise every resizable window
types=161
typesrule=2
maximizehoriz=true
maximizehorizrule=2
maximizevert=true
maximizevertrule=2

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

[duo-tsukimi-player]
Description=Tsukimi mpv player fullscreen on the top panel
wmclass=mpv
wmclassmatch=2
types=1
typesrule=2
fullscreen=true
fullscreenrule=2
screen=0
screenrule=2
EOF

chown duo:duo "$CFG"
echo "=== kwinrulesrc"
sed 's/^/  /' "$CFG"

echo
echo "=== reload kwin"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 qdbus6 org.kde.KWin /KWin reconfigure' 2>&1 | head -2
sleep 1
echo "  kwin: $(su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active plasma-kwin_wayland' 2>/dev/null)"
