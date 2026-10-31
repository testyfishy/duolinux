#!/bin/bash
# Put DP-1 directly below DSI-1. The top panel is 1200x675 logical at scale 1.6,
# so the bottom screen must start at y=675, not 618 (the old 1.75 geometry).
set -u
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 kscreen-doctor output.DP-1.position.0,675' 2>&1 | tail -2
sleep 3

cat > /tmp/geo2.py <<'PY'
import json, subprocess
out = subprocess.run(['kscreen-doctor', '-j'], capture_output=True, text=True).stdout
d = json.loads(out)
for o in d.get('outputs', []):
    if o.get('name') in ('DSI-1', 'DP-1'):
        sc = o.get('scale') or 1
        w, h = o['size']['width'], o['size']['height']
        p = o.get('pos', {})
        print(f"{o['name']}: {w}x{h} scale {sc} -> {w/sc:g}x{h/sc:g} at ({p.get('x')},{p.get('y')})")
PY
chmod 644 /tmp/geo2.py
echo "=== after"
su - duo -c 'HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 python3 /tmp/geo2.py' 2>&1
