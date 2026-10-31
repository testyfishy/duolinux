#!/usr/bin/env python3
"""Replace the generic touch mapping with per-panel mappings."""
import pathlib

p = pathlib.Path("/etc/sway/config")
t = p.read_text()

# remove the generic line and any old specific ones
lines = [l for l in t.splitlines()
         if "map_to_output" not in l]
t = "\n".join(lines) + "\n"

t = t.rstrip() + """

# Touchscreens: keep each on its own panel. Unmapped touch is spread across the
# whole layout, which made the other screen react to taps.
input "0:0:Himax_Touchscreen" map_to_output DSI-1
input "0:0:generic_ft5x06_(a0)" map_to_output DP-1

focus_on_window_activation none
mouse_warping none
"""

p.write_text(t)
print("config rewritten")
print("touch lines now:")
for line in t.splitlines():
    if "input" in line or "mouse_warping" in line or "focus_on_window" in line:
        print("  " + line)
