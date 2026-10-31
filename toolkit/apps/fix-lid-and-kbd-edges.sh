#!/bin/bash
# 1) Make PowerDevil sleep on lid close (upstream behaviour), now that the
#    external-monitor suppression is off and duo-lid is disabled.
# 2) Remove wvkbd's corner rounding, which is the only thing that can show
#    background at the keyboard's edges.
set -u
CFG=/home/duo/.config/powerdevilrc
cp -p "$CFG" "/tmp/powerdevilrc.bak2.$(date +%H%M%S)"

python3 - "$CFG" <<'PY'
import io, re, sys
p = sys.argv[1]
text = io.open(p).read().splitlines()
out, current = [], None
for ln in text:
    s = ln.strip()
    if s.startswith('['):
        current = s
    if current in ('[AC][LidAction]', '[Battery][LidAction]', '[LowBattery][LidAction]'):
        if s.startswith('action='):
            out.append('action=1')      # 1 = Sleep
            continue
    out.append(ln)
io.open(p, 'w').write('\n'.join(out) + '\n')
PY

echo "=== LidAction blocks"
grep -A2 -E "\[(AC|Battery|LowBattery)\]\[LidAction\]" "$CFG"

chown duo:duo "$CFG"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user restart plasma-powerdevil' 2>&1 | head -2
sleep 3
echo "  powerdevil: $(su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active plasma-powerdevil' 2>/dev/null)"

echo
echo "=== keyboard: rounding off, restart"
sed -i 's/-R 10/-R 0/' /usr/local/bin/duo-osk
pkill -x wvkbd-mobintl 2>/dev/null
sleep 1
su - duo -c 'HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 duo-osk show' 2>&1 | head -2
sleep 2
ps -eo args | grep -oE "[w]vkbd-mobintl.*-H [0-9]+.*-R [0-9]+" | head -1
