#!/bin/bash
# Open a page with a focused text field, then report whether the Plasma
# on-screen keyboard (maliit) came up and where.
set -u
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 setsid firefox --new-window "data:text/html,<meta name=viewport content=width=device-width><h1>keyboard test</h1><input autofocus style=font-size:40px;width:90%>" >/dev/null 2>&1 < /dev/null &'
sleep 20
echo "=== maliit processes:"
pgrep -a maliit-keyboard || echo "  maliit not running"
echo "=== kwin child processes:"
pgrep -a kwin_wayland
echo "=== windows:"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 kdotool search --name "." getwindowgeometry 2>/dev/null' || true
