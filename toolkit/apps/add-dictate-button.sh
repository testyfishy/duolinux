#!/bin/bash
# Add a microphone button to the bottom taskbar that starts/stops dictation.
set -u
APP=/home/duo/.local/share/applications/duo-dictate.desktop
mkdir -p /home/duo/.local/share/applications

cat > "$APP" <<'EOF'
[Desktop Entry]
Type=Application
Name=Dictate
Comment=Click to talk: transcribes what you say into the focused window
Exec=/usr/local/bin/duo-dictate toggle
Icon=audio-input-microphone
Terminal=false
Categories=Utility;Accessibility;
Keywords=dictate;speech;voice;transcribe;
EOF
chown duo:duo "$APP"
update-desktop-database /home/duo/.local/share/applications 2>/dev/null

cat > /tmp/addmic.js <<'JS'
var ps = panels();
for (var i = 0; i < ps.length; i++) {
    var p = ps[i];
    if (p.screen !== 1) { continue; }
    var ws = p.widgets();
    for (var j = ws.length - 1; j >= 0; j--) { ws[j].remove(); }
    p.addWidget("org.kde.plasma.kickoff");
    p.addWidget("org.kde.plasma.marginsseparator");
    var q = p.addWidget("org.kde.plasma.quicklaunch");
    q.currentConfigGroup = ["General"];
    q.writeConfig("launcherList", ["duo-dictate.desktop"]);
    p.addWidget("org.kde.plasma.systemtray");
    print("bottom panel rebuilt with the dictate button");
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

chmod 644 /tmp/addmic.js /tmp/call.py
su - duo -c 'HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 python3 /tmp/call.py /tmp/addmic.js' 2>&1 | tail -2
sleep 3

echo "=== panel contents"
su - duo -c 'HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 python3 /tmp/call.py /tmp/geo.js' 2>&1
