#!/usr/bin/env python3
"""Prove that events injected into the virtual DualSense reach other readers."""
import os
import struct
import subprocess
import sys
import threading
import time

DEV = "/dev/input/event11"
EV_KEY = 0x01
KEY_F1 = 59

seen = []


def reader():
    fd = os.open(DEV, os.O_RDONLY)
    end = time.time() + 5
    while time.time() < end:
        try:
            data = os.read(fd, 24)
        except OSError:
            break
        if len(data) < 24:
            break
        _s, _u, kind, code, value = struct.unpack("@llHHi", data)
        if kind == EV_KEY:
            seen.append((code, value))
    os.close(fd)


thread = threading.Thread(target=reader)
thread.start()
time.sleep(0.5)

# inject via a second writer, exactly like the back button would
fd = os.open(DEV, os.O_WRONLY)
now = time.time()
sec, usec = int(now), int((now % 1) * 1_000_000)
os.write(fd, struct.pack("@llHHi", sec, usec, EV_KEY, KEY_F1, 1))
os.write(fd, struct.pack("@llHHi", sec, usec, 0, 0, 0))
time.sleep(0.08)
os.write(fd, struct.pack("@llHHi", sec, usec, EV_KEY, KEY_F1, 0))
os.write(fd, struct.pack("@llHHi", sec, usec, 0, 0, 0))
os.close(fd)

thread.join()
print("events seen by a second reader:", seen)
print("backkey service state:")
print(subprocess.run(["systemctl", "--user", "is-active", "duo-backkey.service"],
                     capture_output=True, text=True,
                     env={**os.environ, "XDG_RUNTIME_DIR": "/run/user/1000"}).stdout.strip())
