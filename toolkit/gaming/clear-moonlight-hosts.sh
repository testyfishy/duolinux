#!/bin/sh
# Stop Moonlight, wipe every stored host (they accumulate one per attempted
# pairing with a new UUID), then start it once with an empty host list.
set -u
APP=com.moonlight_stream.Moonlight
CONF="/home/duo/.var/app/$APP/config/Moonlight Game Streaming Project/Moonlight.conf"

pkill -f "$APP" 2>/dev/null
pkill -x moonlight 2>/dev/null
sleep 3
echo "  running after kill: $(pgrep -fc moonlight)"

cp -p "$CONF" "/tmp/Moonlight.conf.bak.$(date +%H%M%S)"

echo "=== hosts before"
grep -cE "^[0-9]+\\\\hostname=" "$CONF"

python3 - "$CONF" <<'PY'
import io, re, sys
p = sys.argv[1]
out, in_hosts = [], False
for ln in io.open(p).read().splitlines():
    s = ln.strip()
    if s == "[hosts]":
        in_hosts = True
        out.append(ln)
        continue
    if s.startswith("[") and s != "[hosts]":
        in_hosts = False
    if in_hosts and re.match(r'^(\d+)\\|^size=', ln):
        continue
    out.append(ln)
io.open(p, "w").write("\n".join(out) + "\n")
PY

echo "=== hosts after"
grep -cE "^[0-9]+\\\\hostname=" "$CONF" || true
echo "  (0 means the list is empty; Moonlight will discover the host again)"

chown duo:duo "$CONF"

su - duo -c "HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 \
    nohup flatpak run $APP >/tmp/moonlight-gui.log 2>&1 &"
sleep 7
echo "=== running: $(pgrep -fc moonlight)"
echo "=== hosts after start"
grep -E "^[0-9]+\\\\hostname=" "$CONF" 2>/dev/null | head -5
