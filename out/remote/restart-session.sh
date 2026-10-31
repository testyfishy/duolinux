#!/bin/bash
# Restart the Sway session and verify it came back with the new config.
set -u
echo "=== before"
pgrep -a sway | head -3

pkill -x sway 2>/dev/null || true
sleep 8

echo "=== after"
pgrep -a sway | head -3

echo "=== session log tail"
tail -25 /home/duo/.local/state/duo/session.log 2>/dev/null

echo "=== outputs (as duo)"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 swaymsg -t get_outputs' 2>&1 | grep -E 'Output|current mode|scale|position' | head -20

echo "=== fuzzel / i3status running?"
pgrep -a i3status | head -2
pgrep -a foot | head -2

echo "=== bar present (sway processes)"
pgrep -a swaybar | head -2
