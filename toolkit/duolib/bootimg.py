"""Android boot image (header v2) packer/unpacker.

Qualcomm ABL, fastboot and most recovery tools understand this format. We keep the
implementation here so the build has no dependency on AOSP's mkbootimg.
"""

from __future__ import annotations

import hashlib
import struct
from dataclasses import dataclass
from pathlib import Path

MAGIC = b"ANDROID!"
PAGE = 4096

# v2 header: 8 + 4*10 + 16 + 512 + 32 + 1024 + 4 + 8 + 4 + 4 + 8 = 1660
_HDR_V2 = struct.Struct("<8s10I16s512s32s1024sIQIIQ")


@dataclass
class BootImage:
    kernel: bytes
    ramdisk: bytes = b""
    second: bytes = b""
    dtb: bytes = b""
    cmdline: str = ""
    name: str = "duolinux"
    page_size: int = PAGE
    kernel_addr: int = 0x00008000
    ramdisk_addr: int = 0x01000000
    second_addr: int = 0x00F00000
    tags_addr: int = 0x00000100
    dtb_addr: int = 0x01F00000
    header_version: int = 2


def _pad(data: bytes, page: int) -> bytes:
    rem = len(data) % page
    return data if rem == 0 else data + b"\x00" * (page - rem)


def pack(img: BootImage, out: Path) -> Path:
    if len(img.name.encode()) > 15:
        raise ValueError("boot image name must be <= 15 bytes")
    cmd = img.cmdline.encode()
    if len(cmd) > 511:
        raise ValueError("cmdline too long for header v2")
    digest = hashlib.sha1(img.kernel + img.ramdisk + img.second + img.dtb).digest()
    id32 = digest.ljust(32, b"\x00")

    hdr = _HDR_V2.pack(
        MAGIC,
        len(img.kernel), img.kernel_addr,
        len(img.ramdisk), img.ramdisk_addr,
        len(img.second), img.second_addr,
        img.tags_addr,
        img.page_size,
        img.header_version,
        0,  # os_version
        img.name.encode().ljust(16, b"\x00"),
        cmd.ljust(512, b"\x00"),
        id32,
        b"".ljust(1024, b"\x00"),
        0, 0,  # recovery_dtbo_size, offset
        _HDR_V2.size,
        len(img.dtb), img.dtb_addr,
    )
    if len(hdr) != 1660:
        raise AssertionError(f"unexpected header size {len(hdr)}")

    blob = bytearray()
    blob += _pad(hdr, img.page_size)
    blob += _pad(img.kernel, img.page_size)
    if img.ramdisk:
        blob += _pad(img.ramdisk, img.page_size)
    if img.second:
        blob += _pad(img.second, img.page_size)
    if img.dtb:
        blob += _pad(img.dtb, img.page_size)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(bytes(blob))
    return out


def unpack(path: Path) -> BootImage:
    data = path.read_bytes()
    fields = _HDR_V2.unpack_from(data, 0)
    (magic, ksize, kaddr, rsize, raddr, ssize, saddr, tags, page,
     hver, _os, name, cmdline, _id, _extra, _rdtbo_sz, _rdtbo_off,
     _hsize, dsize, daddr) = fields
    if magic != MAGIC:
        raise ValueError("not an Android boot image")
    off = page
    kernel = data[off:off + ksize]; off += _round(ksize, page)
    ramdisk = data[off:off + rsize]; off += _round(rsize, page)
    second = data[off:off + ssize]; off += _round(ssize, page)
    dtb = data[off:off + dsize] if dsize else b""
    return BootImage(
        kernel=kernel, ramdisk=ramdisk, second=second, dtb=dtb,
        cmdline=cmdline.split(b"\x00")[0].decode(errors="replace"),
        name=name.split(b"\x00")[0].decode(errors="replace"),
        page_size=page, kernel_addr=kaddr, ramdisk_addr=raddr,
        second_addr=saddr, tags_addr=tags, dtb_addr=daddr,
        header_version=hver,
    )


def _round(n: int, page: int) -> int:
    return ((n + page - 1) // page) * page
