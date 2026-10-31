#!/usr/bin/env python3
"""Idle-state audit: where CPU time and deep-sleep states actually go.

Samples for 30 s and reports:
  * system idle percentage and the busiest processes
  * cpuidle state residency deltas (are we reaching the deep states?)
  * any disabled idle states, the governor, and PM QoS latency constraints
  * systemd inhibitors that would block suspend
  * interrupt sources that are waking the CPU
"""
import glob
import os
import subprocess
import time

WINDOW = 30


def cpu_times():
    with open("/proc/stat") as handle:
        fields = [int(v) for v in handle.readline().split()[1:]]
    idle = fields[3] + fields[4]
    return sum(fields), idle


def proc_cpu():
    usage = {}
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        try:
            with open(f"/proc/{entry}/stat") as handle:
                parts = handle.read().rsplit(")", 1)[1].split()
            usage[entry] = int(parts[11]) + int(parts[12])
        except (OSError, IndexError):
            continue
    return usage


def proc_name(pid):
    try:
        with open(f"/proc/{pid}/comm") as handle:
            return handle.read().strip()
    except OSError:
        return "?"


def idle_states():
    states = {}
    for cpu_dir in sorted(glob.glob("/sys/devices/system/cpu/cpu[0-9]*/cpuidle/state*")):
        name = open(f"{cpu_dir}/name").read().strip()
        usage = int(open(f"{cpu_dir}/usage").read().strip())
        total = int(open(f"{cpu_dir}/time").read().strip())
        disabled = int(open(f"{cpu_dir}/disable").read().strip())
        key = (name, disabled)
        u, t = states.get(key, (0, 0))
        states[key] = (u + usage, t + total)
    return states


def interrupts():
    counters = {}
    with open("/proc/interrupts") as handle:
        for line in handle:
            parts = line.split()
            if not parts or not parts[0].rstrip(":").isdigit():
                continue
            label = " ".join(parts[-2:]) if len(parts) > 2 else ""
            try:
                counters[label] = sum(int(v) for v in parts[1:len(parts)])
            except ValueError:
                continue
    return counters


clk = os.sysconf("SC_CLK_TCK")
total0, idle0 = cpu_times()
per0 = proc_cpu()
states0 = idle_states()
int0 = interrupts()

time.sleep(WINDOW)

total1, idle1 = cpu_times()
per1 = proc_cpu()
states1 = idle_states()
int1 = interrupts()

busy = 100.0 * (1 - (idle1 - idle0) / max(1, total1 - total0))
print(f"system busy: {busy:.1f}%   idle: {100 - busy:.1f}%   "
      f"load {open('/proc/loadavg').read().split()[0]}")

print("\nbusiest processes:")
deltas = []
for pid in set(per0) & set(per1):
    delta = per1[pid] - per0[pid]
    if delta > 0:
        deltas.append((delta, pid))
for delta, pid in sorted(deltas, reverse=True)[:8]:
    pct = 100.0 * delta / (clk * WINDOW)
    print(f"  {proc_name(pid)[:22]:22} {pct:5.1f}%")

print("\ncpuidle residency over the window:")
for (name, disabled), (usage, total) in sorted(states1.items()):
    du = usage - states0.get((name, disabled), (usage, total))[0]
    dt = total - states0.get((name, disabled), (usage, total))[1]
    dt_ms = dt / 1000.0
    flag = " DISABLED" if disabled else ""
    print(f"  {name:12} entries={du:6}  time={dt_ms:8.1f}ms{flag}")

print("\ngovernors:", " ".join(
    open(p).read().strip()
    for p in sorted(glob.glob("/sys/devices/system/cpu/cpufreq/policy*/scaling_governor"))))

for path in ("/sys/power/pm_qos_resume_latency_us", "/sys/power/mem_sleep"):
    try:
        print(f"{path}: {open(path).read().strip()}")
    except OSError:
        pass

print("\ninhibitors:")
print(subprocess.run(["systemd-inhibit", "--list", "--no-pager"],
                     capture_output=True, text=True).stdout.strip() or "  none")

print("\ntop interrupt sources in the window:")
for label, count in sorted(((k, int1[k] - int0.get(k, 0)) for k in int1),
                           key=lambda kv: kv[1], reverse=True)[:5]:
    if count > 0:
        print(f"  {label[:40]:40} +{count}")
