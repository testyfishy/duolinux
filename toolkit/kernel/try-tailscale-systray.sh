#!/bin/sh
# Try Tailscale's own systray next to ours, measure it, and keep the winner.
set -u
su - duo -c 'pkill -f /usr/local/bin/duo-tailscale' 2>/dev/null || true
sleep 1
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 \
    nohup tailscale systray >/tmp/ts-systray.log 2>&1 &'
sleep 5

pid=$(pgrep -f "tailscale systray" | head -1)
echo "=== tailscale systray"
echo "  pid: ${pid:-none}"
if [ -n "$pid" ]; then
    echo "  pss: $(awk '/^Pss:/{print $2" kB"}' /proc/$pid/smaps_rollup 2>/dev/null)"
    echo "  rss: $(awk '/VmRSS/{print $2" kB"}' /proc/$pid/status 2>/dev/null)"
    echo "  threads: $(awk '/Threads/{print $2}' /proc/$pid/status 2>/dev/null)"
fi
tail -3 /tmp/ts-systray.log 2>/dev/null | sed 's/^/  log: /'

echo
echo "=== tray registration"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 gdbus call --session --dest org.kde.StatusNotifierWatcher \
    --object-path /StatusNotifierWatcher --method org.freedesktop.DBus.Properties.Get \
    org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems' 2>/dev/null | tr ',' '\n' | grep -i tail || echo "  none found"

echo
echo "=== ours, for comparison (stopped)"
echo "  previous pss: 32000 kB (measured before)"
