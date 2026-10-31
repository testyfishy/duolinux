#!/bin/bash
set -u

echo "=== disable the Sway-era waybar (Plasma has its own panel)"
su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 systemctl --user disable --now waybar.service" 2>&1 | tail -2
su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 systemctl --user mask waybar.service" 2>&1 | tail -2
pkill -x waybar 2>/dev/null || true

echo "=== create the missing Desktop folder (Folder View error)"
install -d -o duo -g duo /home/duo/Desktop
ls -ld /home/duo/Desktop

echo "=== persisted output config"
python3 - <<'PY'
import json, pathlib
p = pathlib.Path("/home/duo/.config/kwinoutputconfig.json")
try:
    data = json.loads(p.read_text())
except Exception as e:
    print("no kwinoutputconfig:", e)
else:
    for group in data:
        for o in group.get("data", []):
            print(f"  {o['connectorName']:8} enabled={o.get('enabled')} scale={o.get('scale')} transform={o.get('transform')} mode={o['mode']['width']}x{o['mode']['height']}")
        print("  ---")
PY
