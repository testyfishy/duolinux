#!/bin/sh
set -u
echo "=== bus name:"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 busctl --user list --no-legend' 2>/dev/null | grep -i "Solid.PowerManagement" || echo "MISSING"
echo "=== powerdevil:"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active plasma-powerdevil'
echo "=== remove stopgap battery applet:"
cat > /tmp/rm.js <<'JS'
panels().forEach(function (p) {
  p.widgets("org.kde.plasma.battery").forEach(function (w) { w.remove(); });
});
print("removed");
JS
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat /tmp/rm.js)"' 2>&1 | head -2
sleep 4
echo "=== tray battery instance now:"
grep -c 'plugin=org.kde.plasma.battery' /home/duo/.config/plasma-org.kde.plasma.desktop-appletsrc
echo "=== panel widgets:"
cat > /tmp/w.js <<'JS'
print(panels()[0].widgets().map(function (w) { return w.type; }).join(","));
JS
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat /tmp/w.js)"' 2>&1 | head -2
