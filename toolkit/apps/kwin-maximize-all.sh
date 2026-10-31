#!/bin/sh
# Maximise every normal window by default: on 1098x618 the windowed default is
# unusable, and the Start button moves a window between the two panels where it
# should then fill that panel.
set -u
CFG=/home/duo/.config/kwinrulesrc
[ -f "$CFG" ] && cp -p "$CFG" "/tmp/kwinrulesrc.bak.$(date +%H%M%S)"

cat > "$CFG" <<'EOF'
[General]
count=3
rules=duo-maximize-all,desktop-skip-taskbar,duo-moonlight

[duo-maximize-all]
Description=Maximise every normal window
types=1
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
EOF

chown duo:duo "$CFG"
echo "=== rules"
grep -E "^\[|^Description|^maximize|^fullscreen" "$CFG"

echo
echo "=== reload"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 qdbus6 org.kde.KWin /KWin reconfigure' 2>&1 | head -2
echo "  kwin: $(su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active plasma-kwin_wayland' 2>/dev/null)"
