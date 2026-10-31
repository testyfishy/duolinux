#!/usr/bin/env python3
"""Inject KEY_F1 through the duo-on-screen keyboard device (self-test only)."""
import os
import struct
import time

EV_SYN = 0x00
EV_KEY = 0x01
SYN_REPORT = 0
KEY_F1 = 59

target = None
name = None
for line in open("/proc/bus/input/devices"):
    line = line.strip()
    if line.startswith("N: Name="):
        name = line.split("=", 1)[1].strip().strip('"')
    elif line.startswith("H: Handlers=") and name == "duo-on-screen keyboard":
        for handler in line.split("=", 1)[1].split():
            if handler.startswith("event"):
                target = f"/dev/input/{handler}"
                break

if target is None:
    raise SystemExit("duo-on-screen keyboard device not found")

fd = os.open(target, os.O_WRONLY)
now = time.time()
sec, usec = int(now), int((now % 1) * 1_000_000)


def send(kind, code, value):
    os.write(fd, struct.pack("@llHHi", sec, usec, kind, code, value))


send(EV_KEY, KEY_F1, 1)
send(EV_SYN, SYN_REPORT, 0)
time.sleep(0.06)
send(EV_KEY, KEY_F1, 0)
send(EV_SYN, SYN_REPORT, 0)
os.close(fd)
print(f"injected F1 via {target}")
