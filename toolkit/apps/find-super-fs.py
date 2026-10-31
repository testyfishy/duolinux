#!/usr/bin/env python3
"""Locate a filesystem inside the Android super partition.

Reads the raw partition in large chunks and reports ext4 and erofs superblock
candidates, so the vendor image can be mounted read-only at a known offset.
"""
import os
import sys

DEV = sys.argv[1] if len(sys.argv) > 1 else "/dev/disk/by-partlabel/super"
CHUNK = 16 << 20
EXT4 = b"\x53\xef\x00\x00"          # s_magic at fs+1024+0x38, little endian
EROFS = b"\xe2\xe1\xf5\xe0"         # erofs magic at fs+1024

ext4, erofs = [], []
pos = 0
overlap = 4096
with open(DEV, "rb", buffering=0) as f:
    while True:
        buf = f.read(CHUNK)
        if not buf:
            break
        for needle, out in ((EXT4, ext4), (EROFS, erofs)):
            i = buf.find(needle)
            while i >= 0:
                out.append(pos + i)
                i = buf.find(needle, i + 1)
        pos += len(buf)
        if pos % (256 << 20) == 0:
            print("  ...%.1f GiB" % (pos / (1 << 30)), flush=True)

print("scanned %.1f GiB" % (pos / (1 << 30)))
print("ext4 candidates (fs start = offset - 1080):")
for p in ext4[:12]:
    print("  fs at 0x%x (%d)" % (p - 1080, p - 1080))
print("erofs candidates (fs start = offset - 1024):")
for p in erofs[:12]:
    print("  fs at 0x%x (%d)" % (p - 1024, p - 1024))
