#!/usr/bin/env python3
"""Diff the ACF profile's register list against the live amp registers.

The ACF blob is the board's own configuration: if a register in it differs from
what the chip actually holds during playback, the driver either skipped it or
something overwrote it. That is where a missing boost/gain setting would show up.
"""
import io
import re
import struct
import sys

ACF = sys.argv[1] if len(sys.argv) > 1 else "aw883xx_acf.bin"
LIVE = sys.argv[2] if len(sys.argv) > 2 else "/tmp/amp-live.txt"

data = io.open(ACF, "rb").read()
count, = struct.unpack_from("<I", data, 0x30)

sections = []
for n in range(count):
    off = 0x50 + n * 0x40
    if off + 0x40 > len(data):
        break
    typ, = struct.unpack_from("<I", data, off)
    tag, = struct.unpack_from("<I", data, off + 0x14)
    _hash, doff, npair = struct.unpack_from("<III", data, off + 0x20)
    if typ != 2 or doff + npair * 4 > len(data):
        continue
    regs = {}
    for i in range(npair):
        r, v = struct.unpack_from("<HH", data, doff + i * 4)
        regs[r] = v
    sections.append((n, tag, regs))

print("ACF sections: %d" % len(sections))

live = {}
for line in io.open(LIVE):
    m = re.match(r"^\s*([0-9a-fA-F]{2,3}):\s*([0-9a-fA-F]{4,8})", line)
    if m:
        live[int(m.group(1), 16)] = int(m.group(2), 16)
print("live registers read: %d" % len(live))

# section 0 is the profile the driver loads first
for n, tag, regs in sections:
    diff = [(r, v, live[r]) for r in sorted(regs) if r in live and live[r] != v]
    print()
    print("section %d (tag 0x%08x, %d regs): %d differ from live" % (n, tag, len(regs), len(diff)))
    for r, want, got in diff:
        print("  reg 0x%02x: ACF 0x%04x  live 0x%04x" % (r, want, got))

missing = [r for r in sections[0][2] if r not in live]
print()
print("ACF registers the chip did not report (0x00-0x7E only are dumped): %d" % len(missing))
