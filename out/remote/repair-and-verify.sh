#!/bin/sh
# Repair the panel applet sections, restart the shell, and verify.
set -u

cp -f /home/duo/.config/plasma-org.kde.plasma.desktop-appletsrc /tmp/appletsrc.before-repair
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user stop plasma-plasmashell.service' 2>&1
sleep 3

python3 /tmp/repair-panel.py 2>&1
chown duo:duo /home/duo/.config/plasma-org.kde.plasma.desktop-appletsrc

su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user start plasma-plasmashell.service' 2>&1
sleep 40

echo "=== applets now:"
cat > /tmp/l5.js <<'EOS'
print(panels()[0].widgets().map(function (w) { return w.type; }).join(","));
EOS
su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \"\$(cat /tmp/l5.js)\"" 2>&1 | head -2

echo "=== tray items in its containment:"
A=/home/duo/.config/plasma-org.kde.plasma.desktop-appletsrc
grep -A2 "plugin=org.kde.plasma.systemtray" "$A" | grep -E "SystrayContainmentId|plugin" | head -4
grep -cE "^\[Containments\]\[9\]\[Applets\]\[[0-9]+\]$" "$A" | sed 's/^/containment 9 items: /'
grep -cE "^\[Containments\]\[31\]\[Applets\]\[[0-9]+\]$" "$A" | sed 's/^/containment 31 items: /'

P=$(pgrep -x plasmashell | head -1)
echo "=== CPU:"
top -H -b -d 20 -n 2 -p "$P" | awk '/PID USER/{c++} c==2' | head -3

CACHE=$(ls -1 /home/duo/.cache/ksycoca6_* | head -1)
echo "=== cache mtime (stable = no loop): $(stat -c '%y' "$CACHE")"

echo "=== screenshot:"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 spectacle -b -n -o /tmp/panel3.png' 2>&1 | tail -2
ls -l /tmp/panel3.png 2>&1
