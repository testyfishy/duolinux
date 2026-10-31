#!/usr/bin/env python3
"""Capture input timing and system pressure during a 120 s user test.

Writes /tmp/diag.log. The decisive number is the gap between REL_X events from
InputPlumber's virtual mouse: evenly spaced ~8 ms means the input stream is
clean and any stutter is downstream (compositor), while gaps of 16-50 ms point
at scheduling or InputPlumber itself.
"""
import glob
import os
import select
import struct
import time

MOUSE = "InputPlumber Mouse"
PAD = "Retroid Pocket Duo Lite Gamepad"
DURATION = 120

EV_REL, EV_ABS, EV_KEY = 2, 3, 1


def find(names):
    found = {}
    current = None
    for line in open("/proc/bus/input/devices"):
        line = line.strip()
        if line.startswith("N: Name="):
            current = line.split("=", 1)[1].strip().strip('"')
        elif line.startswith("H: Handlers=") and current in names:
            for handler in line.split("=", 1)[1].split():
                if handler.startswith("event"):
                    found[current] = f"/dev/input/{handler}"
                    break
    return found


def cpu_freqs():
    freqs = []
    for path in glob.glob("/sys/devices/system/cpu/cpufreq/policy*/scaling_cur_freq"):
        try:
            freqs.append(int(open(path).read().strip()) // 1000)
        except OSError:
            pass
    return freqs


def hottest():
    best = 0
    for path in glob.glob("/sys/class/thermal/thermal_zone*/temp"):
        try:
            best = max(best, int(open(path).read().strip()) // 1000)
        except OSError:
            pass
    return best


devices = find((MOUSE, PAD))
fds = {}
for name, path in devices.items():
    try:
        fds[os.open(path, os.O_RDONLY | os.O_NONBLOCK)] = name
    except OSError:
        pass

log = open("/tmp/diag.log", "w", buffering=1)
log.write(f"# devices: {devices}\n")
log.write("# t, source, kind, code, value, gap_ms (mouse REL only)\n")

start = time.time()
end = start + DURATION
last_rel = 0.0
last_sample = 0.0

while time.time() < end:
    try:
        readable, _, _ = select.select(list(fds), [], [], 0.2)
    except InterruptedError:
        continue
    for fd in readable:
        try:
            data = os.read(fd, 24 * 64)
        except OSError:
            continue
        for off in range(0, len(data) - 23, 24):
            _s, _u, kind, code, value = struct.unpack("@llHHi", data[off:off + 24])
            if fds[fd] == MOUSE and kind == EV_REL:
                now = time.time()
                gap = (now - last_rel) * 1000 if last_rel else 0.0
                last_rel = now
                if code in (0, 1):
                    log.write(f"{now - start:.3f},mouse,rel,{code},{value},{gap:.1f}\n")
            elif fds[fd] == PAD and kind == EV_ABS and code in (3, 4):
                log.write(f"{time.time() - start:.3f},pad,abs,{code},{value},0\n")

    now = time.time()
    if now - last_sample >= 5:
        last_sample = now
        load = open("/proc/loadavg").read().split()[0]
        pressure = ""
        try:
            pressure = open("/proc/pressure/cpu").read().strip()
        except OSError:
            pass
        log.write(f"# sample load={load} freq={cpu_freqs()} temp={hottest()}C "
                  f"{pressure}\n")

log.close()
print("capture finished", flush=True)
