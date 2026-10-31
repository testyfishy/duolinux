#!/bin/bash
# Print both outputs' geometry and both panels' screens, without inline quoting.
set -u
cat > /tmp/geo.js <<'JS'
var ps = panels();
for (var i = 0; i < ps.length; i++) {
    print("PANEL screen=" + ps[i].screen + " loc=" + ps[i].location +
          " h=" + ps[i].height + " align=" + ps[i].alignment +
          " widgets=" + ps[i].widgets().length);
}
JS

cat > /tmp/geo.py <<'PY'
import json, subprocess
from gi.repository import Gio, GLib

bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
proxy = Gio.DBusProxy.new_sync(bus, Gio.DBusProxyFlags.NONE, None,
    'org.kde.plasmashell', '/PlasmaShell', 'org.kde.PlasmaShell', None)
js = open('/tmp/geo.js').read()
res = proxy.call_sync('evaluateScript', GLib.Variant('(s)', (js,)),
                      Gio.DBusCallFlags.NONE, -1, None)
print(res.unpack()[0])

out = subprocess.run(['kscreen-doctor', '-j'], capture_output=True, text=True).stdout
d = json.loads(out)
for o in d.get('outputs', []):
    sc = o.get('scale') or 1
    w, h = o['size']['width'], o['size']['height']
    lw, lh = w / sc, h / sc
    print(f"OUTPUT {o.get('name')}: {w}x{h} scale {sc} -> {lw:g}x{lh:g} logical "
          f"pos {o.get('pos')} enabled={o.get('enabled')} exact={w % sc == 0 and h % sc == 0}")
PY

chmod 644 /tmp/geo.js /tmp/geo.py
su - duo -c 'HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 python3 /tmp/geo.py' 2>&1
