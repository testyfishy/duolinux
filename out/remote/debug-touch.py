#!/usr/bin/env python3
import json
import subprocess

ident = "0:0:Himax_Touchscreen"
r = subprocess.run(["swaymsg", "input", ident, "map_to_output", "DSI-1"],
                   capture_output=True, text=True)
print("rc:", r.returncode)
print("out:", r.stdout.strip()[:300])
print("err:", r.stderr.strip()[:300])

ins = subprocess.run(["swaymsg", "-t", "get_inputs", "-r"], capture_output=True, text=True).stdout
for i in json.loads(ins):
    if i.get("type") == "touch":
        print({k: v for k, v in i.items() if k in ("identifier", "mapped_to_output", "type", "name")})
