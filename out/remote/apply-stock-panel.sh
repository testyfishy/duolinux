#!/bin/sh
# Restore stock Kickoff + Icons-only Task Manager and verify idle CPU.
#
# plasmashell must be stopped while its config is edited: Plasma rewrites
# plasma-org.kde.plasma.desktop-appletsrc on exit.
set -u

su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user stop plasma-plasmashell.service' 2>&1
sleep 3

python3 /tmp/restore-stock-panel.py 2>&1
chown duo:duo /home/duo/.config/plasma-org.kde.plasma.desktop-appletsrc

su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user start plasma-plasmashell.service' 2>&1
sleep 35

P=$(pgrep -x plasmashell | head -1)
echo "=== active: $(su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active plasma-plasmashell.service' 2>&1)"
echo "=== applets:"
cat > /tmp/l3.js <<'EOS'
print(panels()[0].widgets().map(function (w) { return w.type; }).join(","));
EOS
su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \"\$(cat /tmp/l3.js)\"" 2>&1 | head -2

CACHE=$(ls -1 /home/duo/.cache/ksycoca6_* 2>/dev/null | head -1)
echo "=== cache mtime now:"
stat -c '%y' "$CACHE"
sleep 30
echo "=== cache mtime 30 s later (same = no rebuild loop):"
stat -c '%y' "$CACHE"
echo "=== cache rewrite count (inode change check):"
ls -i "$CACHE"

echo "=== CPU with stock applets:"
top -H -b -d 25 -n 3 -p "$P" | awk '/PID USER/{c++} c>=2' | head -6

echo "=== screenshot:"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 spectacle -b -n -o /tmp/stock.png' 2>&1 | tail -1
identify /tmp/stock.png 2>/dev/null | head -1
