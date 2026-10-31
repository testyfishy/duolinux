#!/usr/bin/env python3
import json
import subprocess

S = subprocess.run(["bash", "-c", "ls /run/user/1000/sway-ipc.*.sock | head -1"],
                   capture_output=True, text=True).stdout.strip()
cmd = (f"su - duo -c 'SWAYSOCK={S} XDG_RUNTIME_DIR=/run/user/1000 "
       f"swaymsg -t get_inputs -r'")
out = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True).stdout
try:
    data = json.loads(out)
except Exception:
    print("could not read inputs:", out[:300])
    raise SystemExit(1)

print("touch devices:")
for i in data:
    if i.get("type") == "touch":
        print("  id:", i["identifier"])
        print("     mapped_to_output:", i.get("mapped_to_output"))
        print("     events:", i.get("libinput", {}).get("send_events"))

print()
print("outputs:")
S2 = subprocess.run(["bash", "-c",
                     f"su - duo -c 'SWAYSOCK={S} XDG_RUNTIME_DIR=/run/user/1000 swaymsg -t get_outputs -r'"],
                    capture_output=True, text=True).stdout
for o in json.loads(S2):
    r = o["rect"]
    print(f"  {o['name']} active={o['active']} pos={r['x']},{r['y']} size={r['width']}x{r['height']} scale={o.get('scale')}")
