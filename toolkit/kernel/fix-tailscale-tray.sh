#!/bin/sh
# One Tailscale tray only, running the upstream systray.
set -u
pkill -f "tailscale systray" 2>/dev/null
pkill -f "/usr/local/bin/duo-tailscale" 2>/dev/null
sleep 2
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 \
    nohup /usr/bin/tailscale systray >/tmp/duo-tailscale.log 2>&1 &'
sleep 5

echo "=== processes"
for p in $(pgrep -f "tailscale systray" 2>/dev/null); do
    pss=$(awk '/^Pss:/{print $2}' "/proc/$p/smaps_rollup" 2>/dev/null)
    echo "  pid $p pss=${pss} kB"
done

echo "=== tray items"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 gdbus call --session \
    --dest org.kde.StatusNotifierWatcher --object-path /StatusNotifierWatcher \
    --method org.freedesktop.DBus.Properties.Get \
    org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems' 2>/dev/null

echo "=== autostart"
grep -E "^Exec=" /home/duo/.config/autostart/duo-tailscale.desktop
