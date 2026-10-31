#!/bin/sh
# Test whether the sycoca loop is feedback from writing the cache file itself.
#
# Runs plasmashell with XDG_CACHE_HOME on tmpfs. If the rebuild storm stops,
# the trigger is the cache write notifying KSycoca about its own file. If it
# continues, the trigger is elsewhere and the cache location is irrelevant.
set -u

su - duo -c 'pkill -x plasmashell; sleep 3'
mkdir -p /tmp/duo-cache
chown duo:duo /tmp/duo-cache

cat > /tmp/run-pl-tmpfs.sh <<'EOS'
export XDG_CACHE_HOME=/tmp/duo-cache
export XDG_RUNTIME_DIR=/run/user/1000
export WAYLAND_DISPLAY=wayland-0
export XDG_MENU_PREFIX=plasma-
export QML_XHR_ALLOW_FILE_READ=1
export QT_LOGGING_RULES='kf.service.*=true;kf.coreaddons.kdirwatch=true'
export QT_MESSAGE_PATTERN='%{time process} %{message}'
exec setsid plasmashell
EOS
chmod +x /tmp/run-pl-tmpfs.sh
chown duo:duo /tmp/run-pl-tmpfs.sh

su - duo -c 'setsid /tmp/run-pl-tmpfs.sh >/tmp/pl-tmpfs.log 2>&1 < /dev/null &'

sleep 45

echo "=== Recreating ksycoca count (45 s):"
grep -c "Recreating ksycoca" /tmp/pl-tmpfs.log
echo "=== ATTRIB events:"
grep -c "ATTRIB" /tmp/pl-tmpfs.log
echo "=== notifyDatabaseChanged:"
grep -c "notifyDatabaseChanged" /tmp/pl-tmpfs.log
echo "=== first and last rebuild:"
grep "Recreating ksycoca" /tmp/pl-tmpfs.log | head -1
grep "Recreating ksycoca" /tmp/pl-tmpfs.log | tail -1
echo "=== log growth over 5 s:"
before=$(wc -l < /tmp/pl-tmpfs.log)
sleep 5
after=$(wc -l < /tmp/pl-tmpfs.log)
echo "$before -> $after lines"

P=$(pgrep -x plasmashell | head -1)
echo "=== CPU:"
top -H -b -d 15 -n 2 -p "$P" | awk '/PID USER/{c++} c==2' | head -3

cat > /tmp/l.js <<'EOS'
print(panels()[0].widgets().map(function (w) { return w.type; }).join(","));
EOS
echo "=== panel applets:"
su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \"\$(cat /tmp/l.js)\"" 2>&1 | head -2

echo "=== cache dir:"
ls -l /tmp/duo-cache | head -5
