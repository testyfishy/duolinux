#!/bin/sh
# Launch a Flatpak app with a COMPLETE desktop session environment.
# Missing DBUS_SESSION_BUS_ADDRESS silently breaks portals and playback.
set -u
APP="${1:?usage: launch-session.sh <flatpak-app-id> [renderer]}"
RENDERER="${2:-}"

pkill -f "$APP" 2>/dev/null
sleep 2

if [ -n "$RENDERER" ]; then
    K=/home/duo/.var/app/$APP/config/glib-2.0/settings/keyfile
    [ -f "$K" ] && sed -i "s/^mpv-renderer=.*/mpv-renderer=$RENDERER/" "$K" && chown duo:duo "$K"
fi

su - duo -c "HOME=/home/duo \
    XDG_RUNTIME_DIR=/run/user/1000 \
    DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
    WAYLAND_DISPLAY=wayland-0 \
    XDG_SESSION_TYPE=wayland \
    XDG_CURRENT_DESKTOP=KDE \
    QT_QPA_PLATFORM=wayland \
    nohup flatpak run $APP >/tmp/${APP##*.}.log 2>&1 &"
sleep 8

echo "  running: $(pgrep -fc "$APP")"
echo "  bus errors in log: $(grep -ac 'session bus\|D-Bus without' /tmp/${APP##*.}.log 2>/dev/null || echo 0)"
echo "  renderer: $(grep '^mpv-renderer=' /home/duo/.var/app/$APP/config/glib-2.0/settings/keyfile 2>/dev/null)"
