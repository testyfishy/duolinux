#!/bin/bash
# Arrange the two panels the way the hardware is built: DSI-1 on top,
# DP-1 directly beneath it, one continuous desktop.
set -u
export XDG_RUNTIME_DIR=/run/user/1000
export WAYLAND_DISPLAY=wayland-0

K() { su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 kscreen-doctor $*"; }

# Top panel: 1920x1080 logical at scale 1.5 -> 1280x720, at 0,0
K output.DSI-1.scale.1.5 output.DSI-1.position.0,0 output.DSI-1.priority.1
# Bottom panel: 1280x960 at scale 1, directly below the top one
K output.DP-1.scale.1 output.DP-1.position.0,720 output.DP-1.priority.2

sleep 2
echo "=== layout now"
K -o | grep -E "Output:|Geometry:|Scale:|Rotation:|enabled|Modes" | sed 's/\x1b\[[0-9;]*m//g'

echo "=== saved config"
ls -l /home/duo/.config/kscreen/ 2>/dev/null
