#!/bin/sh
# Restart the on-screen keyboard and report the height it actually used.
set -u
pkill -x wvkbd-mobintl 2>/dev/null
sleep 1
su - duo -c 'HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 duo-osk restart' 2>&1 | head -3
sleep 3

echo "=== wvkbd arguments"
ps -eo args | grep "[w]vkbd-mobintl" | head -1

echo "=== panel geometry"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 kscreen-doctor -j' 2>/dev/null \
  | python3 -c 'import json,sys
d=json.load(sys.stdin)
for o in d.get("outputs", []):
    sc=o.get("scale") or 1
    print(f"  {o.get(\"name\")}: {o[\"size\"][\"width\"]}x{o[\"size\"][\"height\"]} scale {sc} -> logical {int(o[\"size\"][\"width\"]/sc)}x{int(o[\"size\"][\"height\"]/sc)}")'
