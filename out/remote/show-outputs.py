#!/usr/bin/env python3
import json
import subprocess

out = subprocess.run(
    ["su", "-", "duo", "-c",
     "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 swaymsg -t get_outputs -r"],
    capture_output=True, text=True).stdout
for o in json.loads(out):
    r = o["rect"]
    print(f'{o["name"]:8s} active={o["active"]!s:5s} mode={o.get("current_mode")} '
          f'scale={o.get("scale")} pos={r["x"]},{r["y"]} size={r["width"]}x{r["height"]}')

print("--- inputs")
ins = subprocess.run(
    ["su", "-", "duo", "-c",
     "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 swaymsg -t get_inputs -r"],
    capture_output=True, text=True).stdout
for i in json.loads(ins):
    if i.get("type") == "touch":
        m = i.get("libinput", {}).get("send_events", "")
        print(f'{i["identifier"]:40s} map={i.get("mapped_to_output")} type={i.get("type")}')
