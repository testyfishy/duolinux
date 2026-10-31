#!/usr/bin/env python3
"""Sample where the CPU goes: system-wide and per-process, over a window."""
import collections
import time

INTERVAL = float(__import__("sys").argv[1]) if len(__import__("sys").argv) > 1 else 20.0
CLK = 100  # USER_HZ


def cpu_total():
    with open("/proc/stat") as f:
        parts = f.readline().split()[1:]
    vals = [int(x) for x in parts]
    idle = vals[3] + vals[4]          # idle + iowait
    total = sum(vals[:8])
    return total, idle


def proc_ticks():
    out = {}
    for pid in __import__("os").listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/stat") as f:
                fields = f.read().rsplit(") ", 1)[1].split()
            out[pid] = (int(fields[11]) + int(fields[12]),
                        open(f"/proc/{pid}/comm").read().strip())
        except (OSError, IndexError, ValueError):
            continue
    return out


t0, i0 = cpu_total()
p0 = proc_ticks()
time.sleep(INTERVAL)
t1, i1 = cpu_total()
p1 = proc_ticks()

dt = t1 - t0
busy = 1.0 - (i1 - i0) / dt
cores = __import__("os").cpu_count()
print(f"=== system over {INTERVAL:.0f}s")
print(f"  busy {busy*100:.1f}% of {cores} cores ({busy*cores*100:.0f}% of one core, "
      f"{busy*100:.1f}% total capacity)")
print(f"  idle {(1-busy)*100:.1f}%")

deltas = []
for pid, (ticks, comm) in p1.items():
    if pid in p0:
        d = ticks - p0[pid][0]
        if d > 0:
            deltas.append((d / CLK / INTERVAL * 100, comm, pid))

deltas.sort(reverse=True)
print(f"\n=== per process, % of one core over {INTERVAL:.0f}s")
for pct, comm, pid in deltas[:14]:
    print(f"  {pct:6.2f}%  {comm:<24} pid {pid}")

total_pct = sum(d[0] for d in deltas)
print(f"\n  sum of all processes: {total_pct:.1f}% of one core")
