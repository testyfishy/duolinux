#!/usr/bin/env python3
"""Sample per-process CPU over a window, plus idle time and wakeups."""
import os
import time

CLK = os.sysconf("SC_CLK_TCK")
WATCH = ["duo-backkey", "duo-fan", "inputplumber", "plasmashell",
         "kwin_wayland", "ksystemstats", "baloo_file", "packagekitd"]


def read_stat(pid: int) -> int:
    try:
        with open(f"/proc/{pid}/stat") as handle:
            fields = handle.read().split()
        return int(fields[13]) + int(fields[14])      # utime + stime
    except (OSError, IndexError):
        return -1


def pids_for(name: str) -> list[int]:
    found = []
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        try:
            with open(f"/proc/{entry}/cmdline", "rb") as handle:
                cmd = handle.read().decode("utf-8", "replace")
        except OSError:
            continue
        if name in cmd:
            found.append(int(entry))
    return found


def cpu_total() -> tuple[int, int]:
    with open("/proc/stat") as handle:
        parts = handle.readline().split()[1:]
    values = [int(v) for v in parts]
    return sum(values), values[3] + values[4]        # total, idle+iowait


def ctxt(pid: int) -> int:
    try:
        with open(f"/proc/{pid}/status") as handle:
            for line in handle:
                if line.startswith("voluntary_ctxt_switches"):
                    return int(line.split()[1])
    except OSError:
        pass
    return 0


pids = {name: pids_for(name) for name in WATCH}
before = {p: read_stat(p) for group in pids.values() for p in group}
ctxt_before = {p: ctxt(p) for group in pids.values() for p in group}
total0, idle0 = cpu_total()

time.sleep(20)

total1, idle1 = cpu_total()
idle_pct = 100.0 * (idle1 - idle0) / max(1, total1 - total0)
print(f"idle: {idle_pct:.1f}%   (load {open('/proc/loadavg').read().split()[0]})")
print(f"{'process':16} {'cpu%':>6} {'wakeups/s':>10}")
for name, group in pids.items():
    cpu = 0.0
    wake = 0
    for pid in group:
        after = read_stat(pid)
        if after >= 0 and before.get(pid, -1) >= 0:
            cpu += 100.0 * (after - before[pid]) / (CLK * 20)
        wake += ctxt(pid) - ctxt_before.get(pid, 0)
    if group:
        print(f"{name:16} {cpu:6.1f} {wake / 20:10.1f}")
