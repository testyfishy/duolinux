#!/bin/bash
# Make the bottom bar touch-friendly: thicker panel => larger tray icons and
# more spacing between them. Plasma sizes tray icons from the panel thickness.
set -u
HEIGHT="${1:-64}"

cat > /tmp/thick.js <<JS
var ps = panels();
for (var i = 0; i < ps.length; i++) {
    var p = ps[i];
    if (p.screen === 1) {
        p.height = $HEIGHT;
        print("bottom panel height set to $HEIGHT");
    }
}
JS

chmod 644 /tmp/thick.js
su - duo -c 'HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 python3 /tmp/call.py /tmp/thick.js' 2>&1 | tail -3
sleep 2

echo "=== panels now"
su - duo -c 'HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 python3 /tmp/call.py /tmp/geo.js' 2>&1
