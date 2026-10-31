#!/bin/bash
# 1) taller docked keyboard, 2) which input device carries the back button (KEY_F1)
set -u

echo "=== vboard state"
pgrep -af "python3 /usr/bin/vboard" | head -2
tail -4 /tmp/vboard.log 2>/dev/null

echo "=== raise the docked keyboard to 520 px"
python3 - <<'PY'
import configparser, pathlib
p = pathlib.Path("/home/duo/.config/vboard/settings.conf")
if not p.exists():
    print("  no settings file yet")
else:
    c = configparser.ConfigParser()
    c.read(p)
    if "DEFAULT" not in c:
        c["DEFAULT"] = {}
    c["DEFAULT"]["dock_height"] = "520"
    with open(p, "w") as f:
        c.write(f)
    print("  dock_height =", c["DEFAULT"]["dock_height"])
PY
chown duo:duo /home/duo/.config/vboard/settings.conf 2>/dev/null || true

echo "=== input devices (name + handler)"
grep -E "^N:|^H: Handlers" /proc/bus/input/devices | paste - - | sed 's/Handlers=//' | head -20

echo "=== which devices advertise KEY_F1 (code 59)?"
python3 - <<'PY'
import glob, struct, fcntl, os
EVIOCGBIT = lambda ev, ln: (2 << 30) | ((ln) << 16) | (0x20 + ev)
names = {}
cur = None
for line in open("/proc/bus/input/devices"):
    if line.startswith("N: Name="):
        cur = line.split("=", 1)[1].strip().strip('"')
    elif line.startswith("H: Handlers=") and cur:
        for h in line.split("=", 1)[1].split():
            if h.startswith("event"):
                names[h] = cur
for ev in sorted(names, key=lambda x: int(x[5:])):
    path = f"/dev/input/{ev}"
    try:
        fd = os.open(path, os.O_RDONLY)
    except OSError:
        continue
    buf = bytearray(96)
    try:
        fcntl.ioctl(fd, EVIOCGBIT(1, 96), buf)
    except OSError:
        os.close(fd)
        continue
    os.close(fd)
    has_f1 = bool(buf[59 // 8] & (1 << (59 % 8)))
    if has_f1:
        print(f"  {ev:8} {names[ev]}")
PY
