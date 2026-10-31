#!/usr/bin/env python3
"""Parse Android super partition (LP metadata) and print logical partition extents.

Android's dynamic partitions store a geometry record at offset 4096, a metadata
header, and tables (partitions / extents / groups / block devices). Extents are
listed in 512-byte sectors, so this gives the exact byte offsets of each image
inside `super` - enough to mount one read-only with a loop offset.
"""
import struct
import sys

DEV = sys.argv[1] if len(sys.argv) > 1 else "/dev/disk/by-partlabel/super"
RESERVED = 4096
GEOM_MAGIC = 0x616C4467
META_MAGIC = 0x414C5030
SECTOR = 512

f = open(DEV, "rb", buffering=0)
f.seek(RESERVED)
geom = f.read(52)
magic, struct_size, checksum, meta_max, slot_count, block_size = struct.unpack("<II32sIII", geom[:52])
if magic != GEOM_MAGIC:
    raise SystemExit("bad geometry magic 0x%08x" % magic)
print("geometry: ok, metadata_max=%d slots=%d block_size=%d" % (meta_max, slot_count, block_size))

meta_off = RESERVED + 8192 + meta_max * 0     # reserved + geometry + backup geometry
f.seek(meta_off)
hdr = f.read(256)
magic, major, minor, header_size = struct.unpack("<IHHI", hdr[:12])
if magic != META_MAGIC:
    raise SystemExit("bad metadata magic 0x%08x" % magic)
print("metadata: v%d.%d header_size=%d" % (major, minor, header_size))

# table descriptors follow the checksums
tables_size = struct.unpack("<I", hdr[12 + 32:12 + 32 + 4])[0]
d = 12 + 32 + 4 + 32
desc = []
for _ in range(4):
    off, num, esize = struct.unpack("<III", hdr[d:d + 12])
    desc.append((off, num, esize))
    d += 12
part_desc, ext_desc, group_desc, dev_desc = desc
print("tables: partitions=%d extents=%d groups=%d devices=%d" % (part_desc[1], ext_desc[1], group_desc[1], dev_desc[1]))

def table(desc):
    off, num, esize = desc
    f.seek(meta_off + header_size + off)
    return f.read(num * esize), esize

parts_raw, esize = table(part_desc)
exts_raw, eesize = table(ext_desc)
devs_raw, desize = table(dev_desc)

devs = []
for i in range(dev_desc[1]):
    first_sector, alignment, align_off, size = struct.unpack("<QIIQ", devs_raw[i*desize:i*desize+24])
    name = devs_raw[i*desize+24:i*desize+60].split(b"\0")[0].decode()
    devs.append((name, first_sector, size))
for name, fs, size in devs:
    print("block device: %-12s first_sector=%d size=%d bytes" % (name, fs, size))

extents = []
for i in range(ext_desc[1]):
    base = i * eesize
    num_sectors, target_type, target_data, target_source = struct.unpack("<QIQI", exts_raw[base:base+24])
    extents.append((num_sectors, target_type, target_data, target_source))

print()
print("%-16s %10s  %s" % ("partition", "size", "extents (byte offset in super, length)"))
for i in range(part_desc[1]):
    base = i * esize
    name = parts_raw[base:base+36].split(b"\0")[0].decode()
    attrs, first_ext, num_ext, group = struct.unpack("<IIII", parts_raw[base+36:base+52])
    total = 0
    spans = []
    for k in range(num_ext):
        num_sectors, target_type, target_data, target_source = extents[first_ext + k]
        if target_type == 0:      # linear
            byte_off = target_data * SECTOR
            length = num_sectors * SECTOR
            spans.append("0x%x+0x%x" % (byte_off, length))
            total += length
    print("%-16s %10d  %s" % (name, total, ", ".join(spans[:3]) + (" ..." if len(spans) > 3 else "")))
