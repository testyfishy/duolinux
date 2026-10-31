#!/bin/bash
# Put the start menu on the top bar as well, at the leading edge.
# Plasma's scripting API only appends, so the panel is rebuilt in order:
#   kickoff, marginsseparator, digitalclock, icontasks
set -u
cat > /tmp/addkick.js <<'JS'
var ps = panels();
for (var i = 0; i < ps.length; i++) {
    var p = ps[i];
    if (p.screen !== 0) { continue; }
    var ws = p.widgets();
    for (var j = ws.length - 1; j >= 0; j--) { ws[j].remove(); }
    p.addWidget("org.kde.plasma.kickoff");
    p.addWidget("org.kde.plasma.marginsseparator");
    p.addWidget("org.kde.plasma.digitalclock");
    p.addWidget("org.kde.plasma.icontasks");
    print("top panel rebuilt with kickoff first");
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

chmod 644 /tmp/addkick.js /tmp/call.py
su - duo -c 'HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 python3 /tmp/call.py /tmp/addkick.js' 2>&1 | tail -3
sleep 3

echo "=== panels now"
su - duo -c 'HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 python3 /tmp/call.py /tmp/geo.js' 2>&1
