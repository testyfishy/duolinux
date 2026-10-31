#!/bin/bash
# Bigger, better-spaced tray icons for touch.
#   - panel thickness 80 px (icons can never exceed the panel)
#   - system tray iconSize raised explicitly (default is derived from thickness)
set -u
HEIGHT="${1:-80}"
ICON="${2:-48}"

cat > /tmp/tray.js <<JS
var ps = panels();
for (var i = 0; i < ps.length; i++) {
    var p = ps[i];
    if (p.screen !== 1) { continue; }
    p.height = $HEIGHT;
    var ws = p.widgets();
    for (var j = 0; j < ws.length; j++) {
        if (ws[j].type === "org.kde.plasma.systemtray") {
            ws[j].currentConfigGroup = ["General"];
            ws[j].writeConfig("iconSize", $ICON);
            print("tray iconSize set to $ICON, panel height $HEIGHT");
        }
    }
}
JS

cat > /tmp/call.py <<'PY'
import sys
from gi.repository import Gio, GLib
js = open(sys.argv[1]).read()
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
proxy = Gio.DBusProxy.new_sync(bus, Gio.DBusProxyFlags.NONE, None,
    'org.kde.plasmashell', '/PlasmaShell', 'org.kde.PlasmaShell', None)
res = proxy.call_sync('evaluateScript', GLib.Variant('(s)', (js,)),
                      Gio.DBusCallFlags.NONE, -1, None)
print(res.unpack()[0])
PY

chmod 644 /tmp/tray.js /tmp/call.py
su - duo -c 'HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 python3 /tmp/call.py /tmp/tray.js' 2>&1 | tail -3
sleep 2

echo "=== tray config that was written"
grep -A6 "org.kde.plasma.systemtray" /home/duo/.config/plasma-org.kde.plasma.desktop-appletsrc 2>/dev/null \
  | grep -iE "iconSize|Configuration" | head -5

echo "=== panel heights"
su - duo -c 'HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 python3 /tmp/call.py /tmp/geo.js' 2>&1
