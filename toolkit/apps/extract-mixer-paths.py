#!/usr/bin/env python3
"""Pull the mixer_paths.xml out of a raw slice of the Android super partition.

The vendor image on this device is uncompressed, so the XML is findable as
plain text. Prints the capture paths that matter for the microphone.
"""
import re
import sys

src = sys.argv[1] if len(sys.argv) > 1 else "vendor-slice.bin"
out = sys.argv[2] if len(sys.argv) > 2 else "/tmp/mixer_paths.xml"

data = open(src, "rb").read()
i = data.find(b"<mixer>")
if i < 0:
    raise SystemExit("no <mixer> in slice")
j = data.find(b"</mixer>", i)
xml = data[i:j + 9].decode("utf-8", "replace")
open(out, "w", encoding="utf-8").write(xml)
print("mixer_paths.xml: %d bytes -> %s" % (len(xml), out))

paths = re.findall(r'<path name="([^"]*)"[^>]*>(.*?)</path>', xml, re.S)
print("paths: %d" % len(paths))

for name, body in paths:
    if re.search(r"mic|dmic", name, re.I):
        print("\n--- %s" % name)
        for line in body.strip().splitlines():
            line = line.strip()
            if line:
                print("    " + line)
