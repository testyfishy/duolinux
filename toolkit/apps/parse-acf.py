#!/usr/bin/env python3
"""Parse an Awinic AW88xx ACF profile blob.

Layout observed in aw883xx_acf.bin (aw88166 board profile):
  0x00  u32 magic 0x0a15f908
  0x04  char board id[8]  ("A1901")
  0x18  u32 total size
  0x30  u32 section count
  0x50  section headers, 0x40 bytes each:
        +0x00 u32 type (2 = register list)
        +0x04 char chip[8] ("aw88166")
        +0x10 u32 tag2
        +0x14 u32 profile id / flags
        +0x1c u32 7 (entry kind?)
        +0x20 u32 hash/next
        +0x24 u32 data offset
        +0x28 u32 pair count
        data = pair_count * (u16 reg, u16 val)

Used to find what the vendor's own profiles put in SYSCTRL2 (reg 05), which is
the attenuation counter behind the volume control.
"""
import struct
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "aw883xx_acf.bin"
data = open(path, "rb").read()

magic, = struct.unpack_from("<I", data, 0)
board = data[4:12].split(b"\0")[0].decode("ascii", "replace")
total, = struct.unpack_from("<I", data, 0x18)
count, = struct.unpack_from("<I", data, 0x30)

print("file      %s (%d bytes)" % (path, len(data)))
print("magic     0x%08x" % magic)
print("board     %s" % board)
print("header sz %d (file is %d)" % (total, len(data)))
print("sections  %d" % count)
print()

rows = []
for n in range(count):
    off = 0x50 + n * 0x40
    if off + 0x40 > len(data):
        break
    typ, = struct.unpack_from("<I", data, off)
    chip = data[off+4:off+12].split(b"\0")[0].decode("ascii", "replace")
    tag = struct.unpack_from("<I", data, off + 0x14)[0]
    hashv, doff, npair = struct.unpack_from("<III", data, off + 0x20)
    if typ != 2 or doff + npair * 4 > len(data):
        continue
    regs = {}
    for i in range(npair):
        r, v = struct.unpack_from("<HH", data, doff + i * 4)
        regs[r] = v
    rows.append((n, chip, tag, hashv, doff, npair, regs))

print("parsed %d register sections" % len(rows))
print()

hits = [r for r in rows if 0x05 in r[6]]
print("sections that set reg 0x05 (SYSCTRL2 / attenuation): %d" % len(hits))
for n, chip, tag, hashv, doff, npair, regs in hits:
    v = regs[0x05]
    print("  section %3d  tag=0x%08x  off=0x%06x  pairs=%2d  reg05=0x%04x  field=%d"
          % (n, tag, doff, npair, v, v & 0x3FF))

print()
print("distribution of reg 05 values:", sorted({r[6][5] & 0x3FF for r in hits}))

# A profile that also sets the I2S/clock registers is the playback profile the
# driver loads first; show its register set for context.
if rows:
    n, chip, tag, hashv, doff, npair, regs = rows[0]
    print()
    print("first section register map (section %d, %d pairs):" % (n, npair))
    for r in sorted(regs)[:40]:
        print("  reg 0x%02x = 0x%04x" % (r, regs[r]))
