#!/bin/bash
# Split the two taskbars:
#   top screen  (DSI-1, screen 0): clock + task list only
#   bottom screen (DP-1, screen 1): start menu + system tray only, on the TOP edge
set -u
cat > /tmp/split.js <<'JS'
function strip(panel, keep) {
    var ws = panel.widgets();
    var removed = [];
    for (var i = ws.length - 1; i >= 0; i--) {
        var t = ws[i].type;
        if (keep.indexOf(t) === -1) {
            removed.push(t);
            ws[i].remove();
        }
    }
    return removed.join(",");
}
var ps = panels();
for (var i = 0; i < ps.length; i++) {
    var p = ps[i];
    if (p.screen === 0) {
        var r = strip(p, ["org.kde.plasma.marginsseparator",
                          "org.kde.plasma.digitalclock",
                          "org.kde.plasma.icontasks"]);
        print("top(screen0) removed: " + r);
    } else if (p.screen === 1) {
        var r = strip(p, ["org.kde.plasma.marginsseparator",
                          "org.kde.plasma.kickoff",
                          "org.kde.plasma.systemtray"]);
        p.location = "top";
        print("bottom(screen1) removed: " + r + " location set to top");
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

chmod 644 /tmp/split.js /tmp/call.py
su - duo -c 'HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 python3 /tmp/call.py /tmp/split.js' 2>&1 | tail -4
sleep 3

echo "=== panels now"
su - duo -c 'HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 python3 /tmp/call.py /tmp/geo.js' 2>&1
