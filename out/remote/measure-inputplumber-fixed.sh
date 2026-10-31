#!/bin/sh
# Idle cost of InputPlumber after the idle back-off patch.
set -u

P=$(pgrep -x inputplumber | head -1)
sleep 30

echo "=== threads (20 s sample)"
top -H -b -d 20 -n 2 -p "$P" 2>/dev/null | awk '/^top -/{n++} n==2' | sed -n '6,12p'

echo "=== wakeups/s per thread"
python3 - "$P" <<'PY'
import os, sys, time
pid = sys.argv[1]
base = f"/proc/{pid}/task"

def snap():
    out = {}
    for tid in os.listdir(base):
        try:
            name = open(f"{base}/{tid}/comm").read().strip()
            with open(f"{base}/{tid}/status") as fh:
                v = 0
                for line in fh:
                    if line.startswith("voluntary_ctxt_switches"):
                        v = int(line.split()[1])
            out[tid] = (name, v)
        except OSError:
            pass
    return out

a = snap(); time.sleep(5); b = snap()
rows = sorted(((b[t][1] - a.get(t, b[t])[1], b[t][0], t) for t in b), reverse=True)
for d, name, tid in rows[:6]:
    print(f"{d/5:8.1f}  {name} {tid}")
print("total:", round(sum(r[0] for r in rows) / 5, 1), "per second")
PY

echo "=== process CPU (average since restart) and uptime"
ps -o pid,%cpu,etime,args -p "$P" | tail -1

echo "=== machine idle"
top -b -d 15 -n 2 2>/dev/null | awk '/^top -/{n++} n==2' | sed -n '3,4p'

echo "=== sources/targets"
timeout 10 inputplumber device 0 targets list 2>&1 | sed -n '1,10p'
ls -l /proc/$P/fd 2>/dev/null | grep -c sources

echo "=== cache/log sanity"
journalctl -u inputplumber -n 5 --no-pager 2>&1 | tail -5
