#!/bin/bash
set -u

echo "=== add touch mapping + calmer focus behaviour"
python3 - <<'PY'
import pathlib
p = pathlib.Path("/etc/sway/config")
t = p.read_text()

add = """
# Touchscreens: each stays on its own panel (unmapped touch is spread across
# the whole layout, which made the other screen react to taps).
input "0:0:Himax_Touchscreen" map_to_output DSI-1
input "0:0:generic_ft5x06_(a0)" map_to_output DP-1

# Do not move focus or warp the pointer behind the user's back.
focus_on_window_activation none
mouse_warping none
"""

if "map_to_output DSI-1" not in t:
    # drop the old generic line that mapped every touch device to DSI-1
    t = t.replace("input type:touch map_to_output DSI-1\n", "")
    t = t.rstrip() + "\n" + add
    p.write_text(t)
    print("touch mapping added")
else:
    print("already present")
PY

echo "=== restart the session"
pkill -x sway 2>/dev/null || true
sleep 14
pgrep -a sway | head -1

echo "=== verify mapping"
S=$(ls /run/user/1000/sway-ipc.*.sock | head -1)
su - duo -c "SWAYSOCK=$S XDG_RUNTIME_DIR=/run/user/1000 swaymsg -t get_inputs -r" 2>/dev/null |
python3 -c 'import json,sys
for i in json.load(sys.stdin):
    if i.get("type")=="touch":
        print(" ", i["identifier"], "->", i.get("mapped_to_output"))'
