"""A small busybox initramfs: finds DUOROOT, mounts it, switch_root, rescue shell."""

from __future__ import annotations

import gzip
import io
import lzma
import os
import struct
import tarfile
from pathlib import Path

from . import util
from .config import CACHE, CFG

BUSYBOX = CACHE / "toolchain" / "busybox-arm64"
PKG_URL = "https://deb.debian.org/debian/dists/trixie/main/binary-arm64/Packages.xz"

INIT = r"""#!/bin/busybox sh
export PATH=/bin
/bin/busybox --install -s /bin
mount -t proc proc /proc 2>/dev/null
mount -t sysfs sysfs /sys 2>/dev/null
mount -t devtmpfs devtmpfs /dev 2>/dev/null
mkdir -p /dev/pts /dev/shm /run /boot /newroot
mount -t devpts devpts /dev/pts 2>/dev/null
mount -t tmpfs tmpfs /run 2>/dev/null

BOOT_MOUNTED=0
BOOTDEV="$(blkid -L ROCKNIX 2>/dev/null)"
if [ -n "$BOOTDEV" ]; then
  if mount -t vfat -o rw "$BOOTDEV" /boot 2>/dev/null; then
    BOOT_MOUNTED=1
  fi
fi

say() {
  msg="[$(cut -d' ' -f1 /proc/uptime)] duo-init: $*"
  echo "$msg" > /dev/console 2>/dev/null
  [ "$BOOT_MOUNTED" = "1" ] && echo "$msg" >> /boot/duo-boot.log 2>/dev/null
}
say "start; boot=$BOOTDEV"

rootarg=""
for arg in $(cat /proc/cmdline); do
  case "$arg" in root=*) rootarg="${arg#root=}";; esac
done
say "cmdline root=$rootarg"

find_root() {
  case "$rootarg" in
    LABEL=*)  blkid -L "${rootarg#LABEL=}" ;;
    UUID=*)   blkid -U "${rootarg#UUID=}" ;;
    PARTUUID=*) blkid -t "PARTUUID=${rootarg#PARTUUID=}" -o device ;;
    /dev/*)   echo "$rootarg" ;;
  esac
}
ROOTDEV="$(find_root)"
[ -z "$ROOTDEV" ] && ROOTDEV="$(blkid -L STORAGE)"
[ -z "$ROOTDEV" ] && ROOTDEV="$(blkid -L DUOROOT)"
if [ -z "$ROOTDEV" ]; then
  say "root filesystem not found; available block devices:"
  ls -l /dev/mmcblk* /dev/sd* /dev/nvme* >> /dev/console 2>/dev/null
  say "dropping to rescue shell (type 'exit' to retry)"
  exec /bin/sh
fi
say "root device $ROOTDEV"
mkdir -p /newroot
if ! mount -o rw "$ROOTDEV" /newroot; then
  say "mount failed; rescue shell"
  exec /bin/sh
fi
if [ ! -x /newroot/sbin/init ] && [ ! -x /newroot/usr/lib/systemd/systemd ]; then
  say "no init on $ROOTDEV; rescue shell"
  exec /bin/sh
fi
mkdir -p /newroot/proc /newroot/sys /newroot/dev /newroot/run
mount --move /proc /newroot/proc 2>/dev/null
mount --move /sys /newroot/sys 2>/dev/null
mount --move /dev /newroot/dev 2>/dev/null
say "switch_root"
[ "$BOOT_MOUNTED" = "1" ] && umount /boot 2>/dev/null
exec switch_root /newroot /sbin/init
"""


def _ar_members(data: bytes) -> dict[str, bytes]:
    if not data.startswith(b"!<arch>\n"):
        raise ValueError("not an ar archive")
    off = 8
    out = {}
    while off + 60 <= len(data):
        hdr = data[off:off + 60]
        name = hdr[0:16].decode("ascii", "ignore").strip().rstrip("/")
        size = int(hdr[48:58].decode("ascii").strip())
        off += 60
        out[name] = data[off:off + size]
        off += size + (size & 1)
    return out


def get_busybox() -> Path:
    if BUSYBOX.exists():
        return BUSYBOX
    BUSYBOX.parent.mkdir(parents=True, exist_ok=True)
    util.banner("fetching static busybox (arm64)")
    idx = CACHE / "toolchain" / "Packages.xz"
    if not idx.exists():
        util.download(PKG_URL, idx)
    text = lzma.decompress(idx.read_bytes()).decode("utf-8", "replace")
    filename = None
    for stanza in text.split("\n\n"):
        if "\nPackage: busybox-static\n" in "\n" + stanza + "\n":
            for line in stanza.splitlines():
                if line.startswith("Filename: "):
                    filename = line.split(": ", 1)[1].strip()
            break
    if not filename:
        util.die("could not find busybox-static in the Debian index")
    deb = CACHE / "toolchain" / "busybox.deb"
    util.download("https://deb.debian.org/debian/" + filename, deb)
    members = _ar_members(deb.read_bytes())
    data_name = next(k for k in members if k.startswith("data.tar"))
    raw = members[data_name]
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:*") as t:
        for m in t.getmembers():
            if m.name.endswith("bin/busybox") and m.isfile():
                BUSYBOX.write_bytes(t.extractfile(m).read())
                BUSYBOX.chmod(0o755)
                util.ok(f"busybox {util.human(BUSYBOX.stat().st_size)}")
                return BUSYBOX
    util.die("busybox binary not found inside .deb")


def _newc(entries: list[tuple[str, int, bytes, int]]) -> bytes:
    """entries: (name, mode, data, rdev)"""
    out = bytearray()
    ino = 1
    for name, mode, data, rdev in entries:
        name_b = name.encode() + b"\x00"
        fields = [
            ino, mode, 0, 0, 1, 0, len(data), 0, 0,
            (rdev >> 8) & 0xFF, rdev & 0xFF,
            len(name_b), 0,
        ]
        out += b"070701" + b"".join(f"{v:08x}".encode() for v in fields)
        out += name_b
        out += b"\x00" * ((4 - len(out) % 4) % 4)
        out += data
        out += b"\x00" * ((4 - len(out) % 4) % 4)
        ino += 1
    out += b"070701" + b"0" * 104 + b"TRAILER!!!\x00"
    out += b"\x00" * ((4 - len(out) % 4) % 4)
    return bytes(out)


def build(cmdline: str) -> Path:
    bb = get_busybox()
    entries: list[tuple[str, int, bytes, int]] = [
        (".", 0o040755, b"", 0),
        ("bin", 0o040755, b"", 0),
        ("dev", 0o040755, b"", 0),
        ("proc", 0o040755, b"", 0),
        ("sys", 0o040755, b"", 0),
        ("run", 0o040755, b"", 0),
        ("newroot", 0o040755, b"", 0),
        ("bin/busybox", 0o100755, bb.read_bytes(), 0),
        ("init", 0o100755, INIT.encode(), 0),
        ("duo-init", 0o100755, INIT.encode(), 0),
        ("dev/console", 0o020600, b"", (5 << 8) | 1),
        ("dev/null", 0o020666, b"", (1 << 8) | 3),
    ]
    raw = _newc(entries)
    out = CACHE / "kernel" / "initramfs.cpio.gz"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(gzip.compress(raw, 9))
    util.ok(f"initramfs {util.human(out.stat().st_size)}")
    return out
