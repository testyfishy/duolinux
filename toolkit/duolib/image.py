"""Build the SD-card image: GPT, FAT32 boot partition, ext4 root."""

from __future__ import annotations

import os
import shutil
import struct
import subprocess
import tempfile
import uuid
import zlib
from pathlib import Path

from . import host, util
from .config import CFG, OUT, KERNEL_ARTIFACTS, IMAGE_NAME, BOOTIMG_NAME

SECTOR = 512
ENTRIES = 128
ENTRY_SIZE = 128
ALIGN = 2048  # 1 MiB


def _crc(data: bytes) -> int:
    return zlib.crc32(data) & 0xFFFFFFFF


def _guid(text: str) -> bytes:
    return uuid.UUID(text).bytes_le


def build_gpt(path: Path, total_sectors: int, parts: list[dict]) -> None:
    """parts: [{start, end, type, name, unique?}, ...] (LBA, inclusive)."""
    disk_guid = uuid.uuid4().bytes_le
    entries = bytearray(ENTRIES * ENTRY_SIZE)
    for i, p in enumerate(parts):
        off = i * ENTRY_SIZE
        entries[off:off + 16] = _guid(p["type"])
        entries[off + 16:off + 32] = p.get("unique") or uuid.uuid4().bytes_le
        struct.pack_into("<QQQ", entries, off + 32, p["start"], p["end"], 0)
        name = p.get("name", "")[:35].encode("utf-16le")
        entries[off + 56:off + 56 + len(name)] = name
    entries_crc = _crc(bytes(entries))

    first_usable = 34
    last_usable = total_sectors - 34

    def header(current: int, backup: int, entry_lba: int) -> bytes:
        h = bytearray(92)
        h[0:8] = b"EFI PART"
        struct.pack_into("<I", h, 8, 0x00010000)
        struct.pack_into("<I", h, 12, 92)
        struct.pack_into("<I", h, 16, 0)  # crc placeholder
        struct.pack_into("<I", h, 20, 0)
        struct.pack_into("<Q", h, 24, current)
        struct.pack_into("<Q", h, 32, backup)
        struct.pack_into("<Q", h, 40, first_usable)
        struct.pack_into("<Q", h, 48, last_usable)
        h[56:72] = disk_guid
        struct.pack_into("<Q", h, 72, entry_lba)
        struct.pack_into("<I", h, 80, ENTRIES)
        struct.pack_into("<I", h, 84, ENTRY_SIZE)
        struct.pack_into("<I", h, 88, entries_crc)
        struct.pack_into("<I", h, 16, _crc(bytes(h)))
        return bytes(h)

    primary = header(1, total_sectors - 1, 2)
    backup = header(total_sectors - 1, 1, total_sectors - 33)

    with path.open("r+b") as f:
        f.seek(0)
        mbr = bytearray(512)
        mbr[446] = 0x00
        mbr[450:454] = struct.pack("<I", 0xEE)
        mbr[454:458] = struct.pack("<I", 1)
        mbr[458:462] = struct.pack("<I", min(total_sectors - 1, 0xFFFFFFFF))
        mbr[510:512] = b"\x55\xaa"
        f.write(mbr)
        f.seek(1 * SECTOR)
        f.write(primary)
        f.seek(2 * SECTOR)
        f.write(entries)
        f.seek((total_sectors - 33) * SECTOR)
        f.write(entries)
        f.seek((total_sectors - 1) * SECTOR)
        f.write(backup)


def parse_gpt(path: Path) -> list[dict]:
    with path.open("rb") as f:
        f.seek(SECTOR)
        hdr = f.read(92)
        if hdr[0:8] != b"EFI PART":
            raise ValueError("not a GPT image")
        entry_lba = struct.unpack_from("<Q", hdr, 72)[0]
        count = struct.unpack_from("<I", hdr, 80)[0]
        size = struct.unpack_from("<I", hdr, 84)[0]
        f.seek(entry_lba * SECTOR)
        entries = f.read(count * size)
    out = []
    for i in range(count):
        e = entries[i * size: (i + 1) * size]
        if len(e) < 128 or e[0:16] == b"\x00" * 16:
            continue
        first, last, _attr = struct.unpack_from("<QQQ", e, 32)
        name = e[56:128].decode("utf-16le", "ignore").split("\x00")[0]
        out.append({"start": first, "end": last, "name": name,
                    "type": str(uuid.UUID(bytes_le=e[0:16]))})
    return out


def _need(commands: list[str]) -> None:
    missing = [c for c in commands if not util.which(c)]
    if missing:
        util.die("missing image tools: " + ", ".join(missing) + "\n  run: duo setup")


def make_fat(src: Path, size_mb: int, label: str, out: Path) -> None:
    _need(["mkfs.vfat", "mcopy"])
    if out.exists():
        out.unlink()
    util.run(["mkfs.vfat", "-F", "32", "-n", label[:11], "-C", str(out), str(size_mb * 1024)], quiet=True)
    out.parent.mkdir(parents=True, exist_ok=True)
    # mtools needs the image path immediately after -i
    for item in sorted(src.iterdir()):
        util.run(["mcopy", "-i", str(out), "-s", str(item), "::"], quiet=True)


def make_ext4(src: Path, size_mb: int, label: str, out: Path) -> None:
    _need(["mke2fs"])
    if out.exists():
        out.unlink()
    out.parent.mkdir(parents=True, exist_ok=True)
    args = [
        "mke2fs", "-q", "-F", "-t", "ext4", "-L", label[:16],
        "-U", str(uuid.uuid4()), "-m", "0", "-O", "^orphan_file",
        "-E", "root_owner=0:0", "-d", str(src), str(out), f"{size_mb}M",
    ]
    util.run([*host.sudo_prefix(), *args])
    util.ok(f"ext4 {label}: {util.human(out.stat().st_size)}")


def write_at(image: Path, offset: int, blob: Path) -> None:
    with image.open("r+b") as dst, blob.open("rb") as src:
        dst.seek(offset)
        shutil.copyfileobj(src, dst, 8 << 20)


def plan(total_mb: int) -> tuple[int, int, int]:
    boot_start = ALIGN
    boot_sectors = CFG.image.boot_mb * 2048
    root_start = boot_start + boot_sectors
    root_start = (root_start + ALIGN - 1) // ALIGN * ALIGN
    overhead = 34 + 2
    root_sectors = total_mb * 2048 - root_start - overhead
    total_sectors = root_start + root_sectors + overhead
    return boot_start, root_start, total_sectors


def assemble(boot_dir: Path, root_dir: Path, out: Path, total_mb: int) -> Path:
    util.banner("assembling SD image")
    boot_start, root_start, total_sectors = plan(total_mb)
    work = Path(tempfile.mkdtemp(prefix="duo-image-"))
    try:
        fat = work / "boot.vfat"
        ext = work / "root.ext4"
        make_fat(boot_dir, CFG.image.boot_mb, CFG.image.boot_label, fat)
        make_ext4(root_dir, (total_sectors * SECTOR // (1 << 20)) - CFG.image.boot_mb - 2,
                  CFG.image.root_label, ext)
        out.parent.mkdir(parents=True, exist_ok=True)
        with out.open("wb") as f:
            f.truncate(total_sectors * SECTOR)
        build_gpt(out, total_sectors, [
            {"start": boot_start, "end": boot_start + CFG.image.boot_mb * 2048 - 1,
             "type": CFG.image.esp_type, "name": CFG.image.boot_label},
            {"start": root_start, "end": root_start + (ext.stat().st_size // SECTOR) - 1,
             "type": CFG.image.linux_type, "name": CFG.image.root_label},
        ])
        write_at(out, boot_start * SECTOR, fat)
        write_at(out, root_start * SECTOR, ext)
        util.ok(f"image {out.name}: {util.human(out.stat().st_size)}")
        return out
    finally:
        shutil.rmtree(work, ignore_errors=True)
