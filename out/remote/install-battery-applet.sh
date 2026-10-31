#!/bin/bash
# The stock battery applet ships in powerdevil-data, which the plasma install
# skipped because it used --no-install-recommends. Install it, drop the local
# stopgap plasmoid, and put the real applet on the panel with a percentage.
set -u
export DEBIAN_FRONTEND=noninteractive

echo "=== install powerdevil (battery applet + power management)"
apt-get -o Acquire::ForceIPv4=true install -y --no-install-recommends \
    powerdevil 2>&1 | tail -4
ls -d /usr/share/plasma/plasmoids/org.kde.plasma.battery 2>/dev/null && echo "applet present"

echo "=== swap the local plasmoid for the stock one"
cat > /tmp/swap.js <<'EOF'
var panel = null;
panels().forEach(function (p) { if (p.screen === 0) panel = p; });
if (panel === null && panels().length) panel = panels()[0];
if (panel === null) {
    print("no panel");
} else {
    panel.widgets().forEach(function (w) {
        if (w.type === "org.duo.battery") {
            try { w.remove(); print("removed local plasmoid"); } catch (e) { print("remove failed: " + e); }
        }
    });
    var have = null;
    panel.widgets().forEach(function (w) {
        if (w.type === "org.kde.plasma.battery") have = w;
    });
    if (have === null) {
        have = panel.addWidget("org.kde.plasma.battery");
        print("added stock battery applet");
    }
    have.currentConfigGroup = ["General"];
    have.writeConfig("showPercentage", true);
    print("percentage: " + have.readConfig("showPercentage"));
}
EOF
chmod 644 /tmp/swap.js
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat /tmp/swap.js)"' 2>&1 | tail -4

echo "=== restart plasmashell with the full session environment"
su - duo -c 'pkill -x plasmashell' 2>/dev/null || true
sleep 2
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 XDG_MENU_PREFIX=plasma- QML_XHR_ALLOW_FILE_READ=1 setsid plasmashell >/tmp/plasmashell.log 2>&1 < /dev/null &'
sleep 10
echo "=== battery applet errors?"
grep -i "battery" /tmp/plasmashell.log | tail -3
echo "=== panel widgets"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat /tmp/list.js)"' 2>&1 | tail -2
