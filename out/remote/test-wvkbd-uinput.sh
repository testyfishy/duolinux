#!/bin/bash
# Swap in the uinput-capable keyboard, retire vboard, and prove the keyboard
# can create a real input device on Plasma.
set -u

echo "=== stop vboard (kept installed, just not used)"
su - duo -c 'pkill -f "python3 /usr/bin/vboard"' 2>/dev/null || true
sleep 1

echo "=== install the new wvkbd"
install -m 755 /root/wvkbd-0.15/wvkbd-mobintl /usr/local/bin/wvkbd-mobintl
ls -l /usr/local/bin/wvkbd-mobintl

echo "=== keyboard height from the duo config"
cat /home/duo/.config/duo/kbd-height 2>/dev/null || echo "  (default 560)"

echo "=== start it on DP-1"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 /usr/local/bin/duo-osk show' 2>&1 | tail -3
sleep 3
pgrep -af wvkbd-mobintl | head -2

echo "=== uinput device created?"
ls /dev/input/by-path/ 2>/dev/null | head -10
grep -B2 -A2 "duo-on-screen" /proc/bus/input/devices 2>/dev/null | head -12

su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 spectacle -b -n -o /tmp/wv1.png' 2>&1 | tail -1
