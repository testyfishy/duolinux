#!/bin/sh
# Start plasmashell the way the session is meant to: as a systemd user service,
# inheriting XDG_CURRENT_DESKTOP=KDE from the user manager.
#
# The hand-launched plasmashell lacked XDG_CURRENT_DESKTOP, so its expected
# mimeapps extra-file list omitted /usr/share/applications/kde-mimeapps.list.
# Every other KDE process expected it, so the shared sycoca cache was rebuilt
# back and forth forever.
set -u

su - duo -c 'pkill -x plasmashell; sleep 3'

echo "=== enabled?:"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-enabled plasma-plasmashell.service' 2>&1

echo "=== starting service:"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user start plasma-plasmashell.service' 2>&1

sleep 30

echo "=== active?:"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active plasma-plasmashell.service' 2>&1

P=$(pgrep -x plasmashell | head -1)
echo "=== plasmashell pid=$P env:"
tr '\0' '\n' < "/proc/$P/environ" | grep -E '^(XDG_CURRENT_DESKTOP|XDG_SESSION_TYPE|DESKTOP_SESSION|XDG_MENU_PREFIX|XDG_CACHE_HOME|XDG_DATA_DIRS)=' || echo "no XDG_CURRENT_DESKTOP!"

CACHE=$(ls -1 /home/duo/.cache/ksycoca6_* 2>/dev/null | head -1)
echo "=== cache file: ${CACHE:-none}"
echo "=== cache mtime now:"
stat -c '%y' "$CACHE" 2>/dev/null
sleep 25
echo "=== cache mtime 25 s later (unchanged means no rebuild loop):"
stat -c '%y' "$CACHE" 2>/dev/null

echo "=== CPU:"
top -H -b -d 20 -n 2 -p "$P" | awk '/PID USER/{c++} c==2' | head -3

cat > /tmp/l2.js <<'EOS'
print(panels()[0].widgets().map(function (w) { return w.type; }).join(","));
EOS
echo "=== panel applets:"
su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \"\$(cat /tmp/l2.js)\"" 2>&1 | head -2

echo "=== workspace target deps (should pull plasmashell in):"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user list-dependencies --plain plasma-workspace.target' 2>&1 | head -20
