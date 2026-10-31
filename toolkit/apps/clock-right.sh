#!/bin/bash
# Top bar: launcher, task list, expanding spacer, clock on the far right.
set -u
cat > /tmp/clock.js <<'JS'
var ps = panels();
for (var i = 0; i < ps.length; i++) {
    var p = ps[i];
    if (p.screen !== 0) { continue; }
    var ws = p.widgets();
    for (var j = ws.length - 1; j >= 0; j--) { ws[j].remove(); }
    p.addWidget("org.kde.plasma.kickoff");
    p.addWidget("org.kde.plasma.marginsseparator");
    p.addWidget("org.kde.plasma.icontasks");
    var spacer = null;
    try { spacer = p.addWidget("org.kde.plasma.panelspacer"); }
    catch (e) { print("spacer failed: " + e); }
    p.addWidget("org.kde.plasma.digitalclock");
    print("top panel rebuilt: kickoff, tasks, spacer, clock");
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

chmod 644 /tmp/clock.js /tmp/call.py
su - duo -c 'HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 python3 /tmp/call.py /tmp/clock.js' 2>&1 | tail -3
sleep 3

echo "=== panels now"
su - duo -c 'HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 python3 /tmp/call.py /tmp/geo.js' 2>&1
