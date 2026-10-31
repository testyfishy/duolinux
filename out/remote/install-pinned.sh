#!/bin/bash
set -u
for f in duo-wifi duo-help duo-settings duo-apps duo-scale duo-session; do
    [ -f "/tmp/ui/$f" ] || continue
    sh -n "/tmp/ui/$f" || { echo "SYNTAX FAIL $f"; exit 1; }
    install -m 755 "/tmp/ui/$f" "/usr/local/bin/$f"
    echo "installed $f"
done

echo "=== restart the session"
pkill -x sway 2>/dev/null || true
sleep 12
pgrep -a sway | head -1
echo "--- keyboard (should exist, hidden, on DP-1):"
pgrep -a wvkbd | cut -c1-80
echo "--- state file (absent = hidden):"
ls /run/user/1000/duo-osk.on 2>/dev/null || echo "  hidden"
echo "--- outputs:"
S=$(ls /run/user/1000/sway-ipc.*.sock | head -1)
su - duo -c "SWAYSOCK=$S XDG_RUNTIME_DIR=/run/user/1000 swaymsg -t get_outputs -r" 2>/dev/null |
python3 -c 'import json,sys
for o in json.load(sys.stdin): print(" ", o["name"], "active="+str(o["active"]))'
