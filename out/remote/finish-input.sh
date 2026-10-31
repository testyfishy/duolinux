#!/bin/bash
# Finish the input/display handover after porting InputPlumber.
set -u

echo "=== make sure my interim remapper is gone (InputPlumber owns the pad now)"
systemctl stop duo-inputd 2>/dev/null || true
systemctl disable duo-inputd 2>/dev/null || true
systemctl mask duo-inputd 2>&1 | tail -1
pgrep -a duo-inputd || echo "duo-inputd not running"

echo "=== install the bottom-screen keyboard helper"
install -m 755 /tmp/duo-osk /usr/local/bin/duo-osk

echo "=== make sure inputplumber is enabled"
systemctl enable inputplumber >/dev/null 2>&1
systemctl is-enabled inputplumber
systemctl is-active inputplumber

echo "=== restart the session so it picks up the new inputs"
pkill -x sway 2>/dev/null || true
sleep 10

echo "=== outputs"
swaymsg -t get_outputs -r 2>/dev/null | head -5 || true
S=$(ls /run/user/1000/sway-ipc.*.sock 2>/dev/null | head -1)
if [ -n "$S" ]; then
  su - duo -c "SWAYSOCK=$S XDG_RUNTIME_DIR=/run/user/1000 swaymsg -t get_outputs -r" 2>/dev/null \
    | python3 -c '
import json,sys
for o in json.load(sys.stdin):
    r=o["rect"]
    print(f"{o[\"name\"]:8s} active={o[\"active\"]!s:5s} pos={r[\"x\"]},{r[\"y\"]} size={r[\"width\"]}x{r[\"height\"]} scale={o.get(\"scale\")}")
'
  echo "=== keyboard/mouse devices visible to sway"
  su - duo -c "SWAYSOCK=$S XDG_RUNTIME_DIR=/run/user/1000 swaymsg -t get_inputs -r" 2>/dev/null \
    | python3 -c '
import json,sys
for i in json.load(sys.stdin):
    if i.get("type") in ("keyboard","pointer","touch"):
        print(f"{i.get(\"type\"):9s} {i[\"identifier\"]}")
'
fi
