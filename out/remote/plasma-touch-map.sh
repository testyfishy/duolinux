#!/bin/bash
# Pin each touchscreen to the panel it physically belongs to.
# KWin's InputDevice objects expose a writable outputName property; without it
# touch is mapped across the whole virtual desktop and lands on the wrong panel.
set -u
# The session bus only accepts the desktop user, so re-run ourselves as duo.
if [ "$(id -u)" = 0 ]; then
    exec su - duo -c "bash $0"
fi
export XDG_RUNTIME_DIR=/run/user/1000
export WAYLAND_DISPLAY=wayland-0

set_output() { # $1 = eventN, $2 = output
    dbus-send --session --print-reply --dest=org.kde.KWin \
        "/org/kde/KWin/InputDevice/$1" \
        org.freedesktop.DBus.Properties.Set \
        string:org.kde.KWin.InputDevice string:outputName "variant:string:$2" >/dev/null 2>&1
    got=$(dbus-send --session --print-reply --dest=org.kde.KWin \
        "/org/kde/KWin/InputDevice/$1" \
        org.freedesktop.DBus.Properties.Get \
        string:org.kde.KWin.InputDevice string:outputName 2>/dev/null |
        grep -o 'string ".*"' | sed 's/string "//;s/"$//')
    printf '  %-8s -> %-6s (read back: %s)\n' "$1" "$2" "$got"
}

echo "=== mapping touchscreens"
for dev in $(dbus-send --session --print-reply --dest=org.kde.KWin /org/kde/KWin/InputDevice \
        org.freedesktop.DBus.Properties.Get \
        string:org.kde.KWin.InputDeviceManager string:devicesSysNames 2>/dev/null |
        grep -o '"event[0-9]*"' | tr -d '"'); do
    name=$(dbus-send --session --print-reply --dest=org.kde.KWin \
        "/org/kde/KWin/InputDevice/$dev" org.freedesktop.DBus.Properties.Get \
        string:org.kde.KWin.InputDevice string:name 2>/dev/null | grep -o 'string ".*"' | head -1)
    case "$name" in
        *Himax*)   set_output "$dev" DSI-1 ;;
        *ft5x06*)  set_output "$dev" DP-1 ;;
    esac
done

echo "=== kcminputrc after setting"
cat /home/duo/.config/kcminputrc 2>/dev/null | head -40
