#!/bin/bash
# Apply the captured KDE display/panel layout to a fresh install.
#
# Run as root on the device, with the desktop session stopped (or from a TTY
# before logging in). plasmashell rewrites appletsrc on exit, so it must not be
# running while the file is replaced.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)/../out/device-config"
[ -d "$SRC" ] || SRC=/opt/duolinux/device-config

USER_HOME=/home/duo
USER_NAME=duo

echo "=== stopping the session so nothing rewrites the config"
su - "$USER_NAME" -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user stop \
    plasma-plasmashell plasma-kwin_wayland 2>/dev/null' || true
sleep 2

echo "=== installing"
install -d -o "$USER_NAME" -g "$USER_NAME" "$USER_HOME/.config"
for f in kwinoutputconfig.json kwinrulesrc plasma-org.kde.plasma.desktop-appletsrc powerdevilrc; do
    if [ -f "$SRC/$f" ]; then
        install -m 600 -o "$USER_NAME" -g "$USER_NAME" "$SRC/$f" "$USER_HOME/.config/$f"
        echo "  $f"
    fi
done

if [ -d "$SRC/kscreen" ] && [ -n "$(ls -A "$SRC/kscreen" 2>/dev/null)" ]; then
    install -d -o "$USER_NAME" -g "$USER_NAME" "$USER_HOME/.local/share/kscreen"
    cp -a "$SRC/kscreen/." "$USER_HOME/.local/share/kscreen/"
    chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.local/share/kscreen"
    echo "  kscreen/"
fi

echo
echo "=== done. Log out and back in (or reboot) for the layout to be applied."
echo "    Expected: DSI-1 1920x1080 @1.6 (1200x675) at 0,0"
echo "              DP-1  1280x960  @1.6 (800x600)  at 0,675"
echo "    Two panels: top (clock right, task list), bottom (launcher + 50 px tray)."
