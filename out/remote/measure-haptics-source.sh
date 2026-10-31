#!/bin/sh
# Measure InputPlumber with and without the haptics source node.
# The file is restored afterwards; this only establishes the cost.
set -u

F=/usr/share/inputplumber/devices/40-retroid_duolite.yaml
cp -f "$F" /tmp/40-retroid_duolite.yaml.orig

P=$(pgrep -x inputplumber | head -1)
echo "=== baseline (2 sources):"
ls -l /proc/$P/fd 2>/dev/null | grep -c sources
top -H -b -d 15 -n 2 -p "$P" 2>/dev/null | awk '/^top -/{n++} n==2' | sed -n '6,10p'

echo "=== removing the haptics source"
python3 - "$F" <<'PY'
import sys, re
p = sys.argv[1]
t = open(p).read()
t = re.sub(r"\n  - group: gamepad\n    evdev:\n      name: aw86927-haptics\n      handler: event\*\n", "\n", t)
open(p, "w").write(t)
print("haptics source removed:", "aw86927" not in t)
PY

systemctl restart inputplumber 2>&1
sleep 30
P=$(pgrep -x inputplumber | head -1)
echo "=== with one source:"
ls -l /proc/$P/fd 2>/dev/null | grep -c sources
top -H -b -d 15 -n 2 -p "$P" 2>/dev/null | awk '/^top -/{n++} n==2' | sed -n '6,10p'
/usr/local/bin/inputplumber devices list 2>&1 | grep -c "Retroid"

echo "=== restoring the original profile"
cp -f /tmp/40-retroid_duolite.yaml.orig "$F"
systemctl restart inputplumber 2>&1
sleep 5
echo "restored: $(systemctl is-active inputplumber)"
