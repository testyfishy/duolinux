#!/bin/bash
# Keyboard pinned to the bottom screen + treat the two panels like two monitors.
set -u
install -m 755 /tmp/duo-osk /usr/local/bin/duo-osk
sh -n /usr/local/bin/duo-osk && echo syntax-ok

echo "=== workspace per output (like separate monitors)"
python3 - <<'PY'
import pathlib
p = pathlib.Path("/etc/sway/config")
t = p.read_text()
t = t.replace("workspace 1 output DSI-1\nworkspace 2 output DSI-1",
              "workspace 1 output DSI-1\nworkspace 2 output DP-1")
if "move container to output DP-1" not in t:
    t = t.rstrip() + """

# Move the focused window between the two panels (USB keyboard).
bindsym $mod+Shift+Right move container to output DP-1
bindsym $mod+Shift+Left move container to output DSI-1
"""
p.write_text(t)
print("workspaces: 1 -> DSI-1 (top), 2 -> DP-1 (bottom)")
PY
grep -n "workspace .* output" /etc/sway/config

echo "=== restart session so the keyboard is created on DP-1"
pkill -x sway 2>/dev/null || true
sleep 12
pgrep -a sway | head -1
echo "--- keyboard:"
pgrep -a wvkbd | cut -c1-90
echo "--- outputs:"
S=$(ls /run/user/1000/sway-ipc.*.sock | head -1)
su - duo -c "SWAYSOCK=$S XDG_RUNTIME_DIR=/run/user/1000 swaymsg -t get_outputs -r" 2>/dev/null |
python3 -c 'import json,sys
for o in json.load(sys.stdin): print(" ", o["name"], "active="+str(o["active"]), o["rect"])'
