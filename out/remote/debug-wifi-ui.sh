#!/bin/bash
set -u
S=$(ls /run/user/1000/sway-ipc.*.sock | head -1)
ENV="SWAYSOCK=$S XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1"

echo "=== launch duo-wifi detached, capture output"
rm -f /tmp/wifi-out.txt
su - duo -c "$ENV sh -c 'nohup /usr/local/bin/duo-wifi > /tmp/wifi-out.txt 2>&1 &'" >/dev/null 2>&1
sleep 4

echo "--- fuzzel processes:"
pgrep -a fuzzel || echo "  none"
echo "--- foot processes:"
pgrep -a foot || echo "  none"
echo "--- output:"
cat /tmp/wifi-out.txt 2>/dev/null || echo "  (no file)"

# clean up whatever opened
pkill -x fuzzel 2>/dev/null || true
sleep 1

echo
echo "=== same test for duo-help"
rm -f /tmp/help-out.txt
su - duo -c "$ENV sh -c 'nohup /usr/local/bin/duo-help > /tmp/help-out.txt 2>&1 &'" >/dev/null 2>&1
sleep 3
pgrep -a fuzzel || echo "  no fuzzel for help either"
cat /tmp/help-out.txt 2>/dev/null || echo "  (no file)"
pkill -x fuzzel 2>/dev/null || true
