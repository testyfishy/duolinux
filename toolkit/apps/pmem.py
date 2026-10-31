#!/usr/bin/env python3
"""Read or write 32-bit words in an MMIO region through /dev/mem.

Kernel rebuilds are ~6 minutes; the DMIC clock registers are two words. This
lets the macro's registers be inspected and poked directly while a capture is
running, so "does bit 0 latch" and "which divider works" become seconds.

Usage:
    pmem.py r 0xa4600c4 [count]
    pmem.py w 0xa4600c4 0x09
    pmem.py seq 0xa4600c4 0.05 20      # sample every 50 ms, 20 times
"""
import mmap
import os
import struct
import sys
import time

PAGE = 0x1000


def _map(addr, size=4, write=False):
    fd = os.open("/dev/mem", os.O_RDWR | os.O_SYNC if write else os.O_RDONLY | os.O_SYNC)
    base = addr & ~(PAGE - 1)
    off = addr - base
    m = mmap.mmap(fd, off + size, mmap.MAP_SHARED,
                  mmap.PROT_READ | mmap.PROT_WRITE if write else mmap.PROT_READ,
                  offset=base)
    return fd, m, off


def read32(addr):
    fd, m, off = _map(addr)
    try:
        return struct.unpack("<I", m[off:off + 4])[0]
    finally:
        m.close()
        os.close(fd)


def write32(addr, value):
    fd, m, off = _map(addr, write=True)
    try:
        m[off:off + 4] = struct.pack("<I", value)
    finally:
        m.close()
        os.close(fd)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    cmd = sys.argv[1]
    addr = int(sys.argv[2], 0)

    if cmd == "r":
        count = int(sys.argv[3]) if len(sys.argv) > 3 else 1
        for i in range(count):
            a = addr + i * 4
            print("0x%08x = 0x%08x" % (a, read32(a)))
    elif cmd == "w":
        value = int(sys.argv[3], 0)
        before = read32(addr)
        write32(addr, value)
        after = read32(addr)
        print("0x%08x: 0x%08x -> wrote 0x%08x -> reads 0x%08x" % (addr, before, value, after))
    elif cmd == "seq":
        interval = float(sys.argv[3])
        count = int(sys.argv[4])
        for _ in range(count):
            print("0x%08x" % read32(addr))
            time.sleep(interval)
    else:
        print(__doc__)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
