#!/bin/bash
# 1) Give the top panel an exact scale (1080/1.6 = 675, 1920/1.6 = 1200).
# 2) Add a second taskbar on the other screen, copying the existing one.
set -u
U='su - duo -c'

echo "=== outputs before"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 kscreen-doctor -o' 2>/dev/null | grep -E "^Output|Scale|Geometry" | head -6

echo
echo "=== set DSI-1 scale to 1.6 (exact; matches DP-1)"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 kscreen-doctor output.DSI-1.scale.1.6' 2>&1 | tail -2
sleep 3

cat > /tmp/mkpanel.js <<'JS'
var ps = panels();
var have = {};
for (var i = 0; i < ps.length; i++) { have[ps[i].screen] = true; }
var target = have[0] ? 1 : 0;
if (have[target]) {
    print("panel already exists on screen " + target);
} else {
    var p = null;
    try { p = new Panel("org.kde.panel"); }
    catch (e) { p = new Panel("org.kde.plasma.panel"); }
    p.location = "bottom";
    p.screen = target;
    p.height = 50;
    p.alignment = "center";
    p.addWidget("org.kde.plasma.marginsseparator");
    p.addWidget("org.kde.plasma.digitalclock");
    p.addWidget("org.kde.plasma.icontasks");
    p.addWidget("org.kde.plasma.kickoff");
    p.addWidget("org.kde.plasma.systemtray");
    print("created panel on screen " + target);
}
JS

cat > /tmp/mkpanel.py <<'PY'
from gi.repository import Gio, GLib
js = open('/tmp/mkpanel.js').read()
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
proxy = Gio.DBusProxy.new_sync(bus, Gio.DBusProxyFlags.NONE, None,
    'org.kde.plasmashell', '/PlasmaShell', 'org.kde.PlasmaShell', None)
res = proxy.call_sync('evaluateScript', GLib.Variant('(s)', (js,)),
                      Gio.DBusCallFlags.NONE, -1, None)
print(res.unpack()[0])
PY

chmod 644 /tmp/mkpanel.js /tmp/mkpanel.py

echo
echo "=== create the second panel"
su - duo -c 'HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 python3 /tmp/mkpanel.py' 2>&1 | tail -4
sleep 2

echo
echo "=== panels now"
su - duo -c 'HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 python3 /tmp/panels.py' 2>&1 | head -12
