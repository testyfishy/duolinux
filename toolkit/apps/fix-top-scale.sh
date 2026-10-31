#!/bin/sh
# 1) Is Wi-Fi actually healthy again?
# 2) Give the top panel an exact scale (no fractional logical size).
set -u
echo "=== wifi health"
echo "  global: $(nmcli -t -f STATE g 2>/dev/null)"
echo "  device: $(nmcli -t -f DEVICE,STATE dev 2>/dev/null | grep wlan)"
iw dev wlan0 link 2>/dev/null | grep -E "SSID|freq|signal|bitrate" | sed 's/^/  /'
echo "  ping gateway: $(ping -c1 -W2 192.168.86.1 >/dev/null 2>&1 && echo ok || echo FAIL)"
echo "  recent driver errors:"
dmesg | grep -iE "ath10k.*(fail|error|-110|timeout)" | tail -4 | sed 's/^/    /'

echo
echo "=== top panel scale: 1080x1920"
echo "  before: $(su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 kscreen-doctor -j' 2>/dev/null | python3 -c 'import json,sys;d=json.load(sys.stdin);[print(f"{o[\"name\"]} scale {o.get(\"scale\")} -> {o[\"size\"][\"width\"]}x{o[\"size\"][\"height\"]}") for o in d[\"outputs\"] if o[\"name\"] in (\"DSI-1\",\"DP-1\")]' 2>/dev/null)"

# 1080/1.6 = 675, 1920/1.6 = 1200 - both exact, and it matches DP-1's 1.6
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 kscreen-doctor output.DSI-1.scale.1.6' 2>&1 | tail -2
sleep 3

echo "  after:"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 kscreen-doctor -j' 2>/dev/null | python3 -c 'import json,sys
d=json.load(sys.stdin)
for o in d.get("outputs", []):
    if o.get("name") in ("DSI-1","DP-1"):
        sc=o.get("scale") or 1
        w=int(o["size"]["width"]/sc); h=int(o["size"]["height"]/sc)
        print(f"  {o[\"name\"]}: scale {sc} -> {w}x{h} logical (exact={o[\"size\"][\"width\"]%sc==0 and o[\"size\"][\"height\"]%sc==0})")'
