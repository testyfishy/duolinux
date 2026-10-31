#!/bin/sh
# Experiments from the review: where do the wakeups come from, and does cutting
# tokio workers or the ds5 target help, all without rebuilding.
set -u

P=$(pgrep -x inputplumber | head -1)
echo "pid=$P"

echo "=== baseline threads (20 s)"
top -H -b -d 20 -n 2 -p "$P" 2>/dev/null | awk '/^top -/{n++} n==2' | sed -n '6,12p'

echo "=== voluntary context switches per thread over 5 s (wakeups/s)"
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

a = snap()
time.sleep(5)
b = snap()
rows = []
for tid, (name, v2) in b.items():
    v1 = a.get(tid, (name, v2))[1]
    rows.append((v2 - v1, name, tid))
rows.sort(reverse=True)
print(f"{'wakeups/s':>10}  {'thread':<20} tid")
for d, name, tid in rows[:12]:
    print(f"{d/5:>10.1f}  {name:<20} {tid}")
print("total:", sum(r[0] for r in rows) / 5, "per second")
PY

echo "=== experiment 1: TOKIO_WORKER_THREADS=2"
mkdir -p /etc/systemd/system/inputplumber.service.d
cat > /etc/systemd/system/inputplumber.service.d/zz-tokio.conf <<'EOF'
[Service]
Environment=TOKIO_WORKER_THREADS=2
EOF
systemctl daemon-reload
systemctl restart inputplumber
sleep 25
P=$(pgrep -x inputplumber | head -1)
echo "threads: $(ls /proc/$P/task | wc -l)"
top -H -b -d 20 -n 2 -p "$P" 2>/dev/null | awk '/^top -/{n++} n==2' | sed -n '6,12p'
ps -o pid,%cpu,etime,args -p "$P" | tail -1

echo "=== device CLI (for the target experiment)"
/usr/local/bin/inputplumber device --help 2>&1 | head -20
