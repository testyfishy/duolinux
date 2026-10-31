#!/usr/bin/env python3
"""Patch the FAT boot partition inside the SD image, in place, same length.

Goals:
  1. console order: make tty0 (the screen) the LAST console, so /dev/console
     goes to the display instead of the UART.  Same length swap.
  2. allow_mismatched_32bit_el0 -> clk_ignore_unused (+ padding).  Same length.

Emits:
  out/patch/patch.bin   the changed 512-byte sectors, concatenated
  out/patch/patch.sh    a flat shell script that writes them to the card
  out/patch/report.txt  the offsets, for the PC-side record
"""
from __future__ import annotations

import pathlib
import sys

SECTOR = 512
P1_START = 2048 * SECTOR          # 1 MiB, where the FAT partition begins
P1_SIZE = 512 * 1024 * 1024       # 512 MiB

SWAPS = [
    (b"console=tty0 console=ttyMSM0,115200n8 ",
     b"console=ttyMSM0,115200n8 console=tty0 "),
    (b"allow_mismatched_32bit_el0",
     b"clk_ignore_unused" + b" " * 9),
]

OUT = pathlib.Path(__file__).resolve().parent
IMG = OUT.parent / "duolinux-duol.img"


def main() -> int:
    if not IMG.exists():
        print(f"missing {IMG}")
        return 1
    if not OUT.exists():
        OUT.mkdir(parents=True)

    with IMG.open("rb") as f:
        f.seek(P1_START)
        p1 = bytearray(f.read(P1_SIZE))
    print(f"read {len(p1)} bytes of partition 1")

    changes: dict[int, bytearray] = {}
    report = []

    for old, new in SWAPS:
        assert len(old) == len(new), (old, new)
        hits = []
        start = 0
        while True:
            i = p1.find(old, start)
            if i < 0:
                break
            hits.append(i)
            start = i + 1
        report.append(f"{old.decode(errors='replace')!r} -> {new.decode(errors='replace')!r}: {len(hits)} hit(s) at {hits}")
        if not hits:
            print(f"ERROR: no hit for {old!r}", file=sys.stderr)
            return 1
        for i in hits:
            p1[i:i + len(old)] = new

    # Group changed bytes by sector.
    for old, new in SWAPS:
        start = 0
        while True:
            i = p1.find(new, start)
            if i < 0:
                break
            start = i + 1
    # Simpler: diff against the untouched read.
    with IMG.open("rb") as f:
        f.seek(P1_START)
        orig = f.read(P1_SIZE)
    for idx in range(len(p1)):
        if p1[idx] != orig[idx]:
            sec = idx // SECTOR
            base = sec * SECTOR
            changes.setdefault(sec, bytearray(p1[base:base + SECTOR]))

    print(f"{len(changes)} sector(s) changed")
    blob = bytearray()
    lines = []
    for n, sec in enumerate(sorted(changes)):
        blob += changes[sec]
        card_sector = (P1_START + sec * SECTOR) // SECTOR
        lines.append(
            f"dd if=/data/local/tmp/duo-patch.bin of=/dev/block/mmcblk1 "
            f"bs=512 skip={n * SECTOR} seek={card_sector} count=1 conv=notrunc 2>/dev/null"
        )
        report.append(f"sector {card_sector} (partition sector {sec})")

    (OUT / "patch.bin").write_bytes(bytes(blob))

    script = "\n".join([
        "#!/system/bin/sh",
        "# Applies a verified set of 512-byte fixes to the microSD boot config.",
        "# Writes only the changed sectors; nothing else on the card is touched.",
        "B=/dev/block/mmcblk1",
        "set -e",
        *lines,
        "sync",
        "echo PATCH-APPLIED",
        "",
    ])
    (OUT / "patch.sh").write_text(script, encoding="utf-8", newline="\n")
    (OUT / "report.txt").write_text("\n".join(report) + "\n", encoding="utf-8")
    print("\n".join(report))
    print(f"wrote {OUT / 'patch.bin'} ({len(blob)} bytes) and patch.sh")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
