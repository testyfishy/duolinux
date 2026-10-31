#!/bin/bash
# Write the vboard window rule correctly: bottom panel, fixed size, above,
# never takes focus (so typing goes to the app on the top screen).
set -u
cat > /etc/xdg/kwinrulesrc <<'EOF'
[General]
rules=vboard
count=1

[vboard]
Description=vboard on the bottom panel
Enabled=true
wmclass=io.github.archisman-panigrahi.vboard
wmclassmatch=1
wmclasscomplete=false
above=true
aboverule=2
acceptfocus=false
acceptfocusrule=2
skiptaskbar=true
skiptaskbarrule=2
skippager=true
skippagerrule=2
position=0,720
positionrule=2
size=1280,430
sizerule=2
noborder=true
noborderrule=2
EOF

echo "=== rule:"; cat /etc/xdg/kwinrulesrc
echo "=== restart vboard"
su - duo -c 'pkill -f "python3 /usr/bin/vboard" 2>/dev/null; sleep 1'
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 setsid vboard >/tmp/vboard.log 2>&1 < /dev/null &'
sleep 9
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 spectacle -b -n -o /tmp/vb2.png' 2>&1 | tail -1
ls -l /tmp/vb2.png
