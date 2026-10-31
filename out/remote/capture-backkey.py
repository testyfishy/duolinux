#!/usr/bin/env python3
"""Log raw key events from InputPlumber's virtual keyboard for 60 s.

If one press of the back button arrives as two KEY_F1 press edges, the toggle
fires twice and the keyboard flashes. This counts them exactly.
"""
import os
import select
import struct
import time

EV_KEY = 0x01
KEY_F1 = 59
KEY_HOME = 102

path = None
name = None
for line in open("/proc/bus/input/devices"):
    line = line.strip()
    if line.startswith("N: Name="):
        name = line.split("=", 1)[1].strip().strip('"')
    elif line.startswith("H: Handlers=") and name == "InputPlumber Keyboard":
        for handler in line.split("=", 1)[1].split():
            if handler.startswith("event"):
                path = f"/dev/input/{handler}"

if path is None:
    raise SystemExit("InputPlumber Keyboard not found")

fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
start = time.time()
with open("/tmp/keys.log", "w", buffering=1) as log:
    log.write(f"# watching {path}\n")
    while time.time() - start < 60:
        try:
            readable, _, _ = select.select([fd], [], [], 0.5)
        except InterruptedError:
            continue
        if not readable:
            continue
        try:
            data = os.read(fd, 24 * 64)
        except OSError:
            break
        for off in range(0, len(data) - 23, 24):
            _s, _u, kind, code, value = struct.unpack("@llHHi", data[off:off + 24])
            if kind == EV_KEY and code in (KEY_F1, KEY_HOME):
                label = "F1" if code == KEY_F1 else "HOME"
                log.write(f"{time.time() - start:6.3f} {label} value={value}\n")
