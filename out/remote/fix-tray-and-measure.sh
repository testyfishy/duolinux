#!/bin/sh
# Re-add the system tray applet, order the panel, then measure steady state.
#
# The tray applet was lost during earlier hand-editing of appletsrc, which is
# why the volume/network icons were missing.
set -u

cat > /tmp/t.js <<'EOS'
var p = panels()[0];
var known = p.widgets().some(function (w) { return w.type === "org.kde.plasma.systemtray"; });
if (!known) { p.addWidget("org.kde.plasma.systemtray"); }
print("systemtray present: " + p.widgets().some(function (w) { return w.type === "org.kde.plasma.systemtray"; }));
EOS
su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \"\$(cat /tmp/t.js)\"" 2>&1 | head -3

sleep 8

# Order it properly (restore script is idempotent and includes the tray).
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user stop plasma-plasmashell.service' 2>&1
sleep 3
python3 /tmp/restore-stock-panel.py 2>&1
chown duo:duo /home/duo/.config/plasma-org.kde.plasma.desktop-appletsrc
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user start plasma-plasmashell.service' 2>&1

# Let startup transients pass before measuring.
sleep 45

P=$(pgrep -x plasmashell | head -1)
CACHE=$(ls -1 /home/duo/.cache/ksycoca6_* | head -1)
echo "=== cache before: $(stat -c '%y %i' "$CACHE")"

echo "=== CPU samples (main thread, 4 x 15 s):"
for i in 1 2 3 4; do
    top -H -b -d 15 -n 2 -p "$P" | awk '/PID USER/{c++} c==2' | sed -n '1p;2p' | head -2
    echo "--"
done

echo "=== thread CPU time growth (should be small):"
top -H -b -n 1 -p "$P" | sed -n '7,12p'

echo "=== cache after: $(stat -c '%y %i' "$CACHE")"
echo "=== sycoca rebuild marker (lock file mtime):"
stat -c '%y' "$CACHE.lock" 2>/dev/null || echo "no lock file"

echo "=== applets:"
cat > /tmp/l4.js <<'EOS'
print(panels()[0].widgets().map(function (w) { return w.type; }).join(","));
EOS
su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \"\$(cat /tmp/l4.js)\"" 2>&1 | head -2

echo "=== screenshot:"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 spectacle -b -n -o /tmp/stock2.png' 2>&1 | tail -2
ls -l /tmp/stock2.png 2>&1
