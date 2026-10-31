#!/bin/sh
# 3 x DPMS off/on. Catches the power-sequence failure mode that works once and
# then fails to unblank.
set -u
run_as() { su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 $*" 2>/dev/null; }

echo "=== before: $(dmesg | grep -icE 'dsi|panel|bridge|dpu') drm lines"
for i in 1 2 3; do
    run_as kscreen-doctor --dpms off
    sleep 3
    run_as kscreen-doctor --dpms on
    sleep 3
    echo "  cycle $i: connectors=$(cat /sys/class/drm/card0-DSI-1/status)/$(cat /sys/class/drm/card0-DP-1/status) errors=$(dmesg | grep -iE 'dsi|panel|bridge|dpu|wl818s' | grep -icE 'error|fail|timeout')"
done

echo "=== backlight now: $(cat /sys/class/backlight/backlight/brightness)/$(cat /sys/class/backlight/backlight/max_brightness)"
echo "=== plasma: $(su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active plasma-plasmashell' 2>/dev/null)"
echo "=== new dmesg errors since boot: $(dmesg | grep -iE 'dsi|panel|bridge|dpu|wl818s' | grep -icE 'error|fail|timeout')"
