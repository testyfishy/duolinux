#!/bin/bash
# Verify the split and set the bottom bar's height, self-contained.
set -u
HEIGHT="${1:-64}"

cat > /tmp/geo.js <<'JS'
var ps = panels();
for (var i = 0; i < ps.length; i++) {
    var p = ps[i];
    var types = [];
    var ws = p.widgets();
    for (var j = 0; j < ws.length; j++) { types.push(ws[j].type.split(".").pop()); }
    print("PANEL " + i + " screen=" + p.screen + " loc=" + p.location +
          " h=" + p.height + " -> " + types.join("+") + "\n");
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

chmod 644 /tmp/geo.js /tmp/call.py
RUN='HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0'

echo "=== before"
su - duo -c "$RUN python3 /tmp/call.py /tmp/geo.js" 2>&1

cat > /tmp/thick.js <<JS
var ps = panels();
for (var i = 0; i < ps.length; i++) {
    if (ps[i].screen === 1) { ps[i].height = $HEIGHT; }
}
JS
chmod 644 /tmp/thick.js
su - duo -c "$RUN python3 /tmp/call.py /tmp/thick.js" >/dev/null 2>&1
sleep 2

echo "=== after"
su - duo -c "$RUN python3 /tmp/call.py /tmp/geo.js" 2>&1
