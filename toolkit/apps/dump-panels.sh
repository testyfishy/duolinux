#!/bin/bash
# Dump Plasma panels via D-Bus from Python, to avoid shell quoting around JS.
set -u
cat > /tmp/panels.js <<'JS'
var ps = panels();
for (var i = 0; i < ps.length; i++) {
    var p = ps[i];
    print("PANEL " + i + " screen=" + p.screen + " loc=" + p.location +
          " h=" + p.height + " align=" + p.alignment);
    var ws = p.widgets();
    for (var j = 0; j < ws.length; j++) {
        print("  WIDGET " + j + " " + ws[j].type);
    }
}
print("SCREENS " + screenCount);
JS

cat > /tmp/panels.py <<'PY'
import sys
from gi.repository import Gio, GLib
js = open('/tmp/panels.js').read()
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
proxy = Gio.DBusProxy.new_sync(bus, Gio.DBusProxyFlags.NONE, None,
    'org.kde.plasmashell', '/PlasmaShell', 'org.kde.PlasmaShell', None)
res = proxy.call_sync('evaluateScript', GLib.Variant('(s)', (js,)),
                      Gio.DBusCallFlags.NONE, -1, None)
print(res.unpack()[0])
PY

chmod 644 /tmp/panels.js /tmp/panels.py
su - duo -c 'HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 python3 /tmp/panels.py' 2>&1
