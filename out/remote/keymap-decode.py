#!/usr/bin/env python3
"""Decode /proc/bus/input/devices key bitmaps to see which devices can send what."""
import re

KEY_NAMES = {59: "KEY_F1", 1: "KEY_ESC", 28: "KEY_ENTER", 57: "KEY_SPACE",
             103: "KEY_UP", 108: "KEY_DOWN", 105: "KEY_LEFT", 106: "KEY_RIGHT",
             15: "KEY_TAB", 139: "KEY_MENU", 158: "KEY_BACK", 102: "KEY_HOME"}

devices = []
cur = {}
for line in open("/proc/bus/input/devices"):
    line = line.rstrip("\n")
    if line.startswith("N: Name="):
        cur = {"name": line.split("=", 1)[1].strip('"')}
    elif line.startswith("B: KEY="):
        cur["key"] = line.split("=", 1)[1].strip()
    elif line.startswith("H: Handlers="):
        cur["handlers"] = line.split("=", 1)[1].strip()
        devices.append(cur)

for dev in devices:
    if not dev.get("key"):
        continue
    words = [int(w, 16) for w in dev["key"].split()]
    # bitmap is little-endian 64-bit words
    bits = 0
    for index, word in enumerate(words):
        bits |= word << (64 * index)
    hits = [KEY_NAMES[c] for c in KEY_NAMES if bits >> c & 1]
    ev = re.search(r"event\d+", dev.get("handlers", ""))
    if hits:
        print(f"{ev.group(0) if ev else '-':8} {dev['name'][:44]:46} {', '.join(hits)}")
