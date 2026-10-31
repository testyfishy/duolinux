#!/usr/bin/env python3
"""Rebuild the 512 MiB ROCKNIX boot partition with a chatty, on-screen initramfs.

Run inside WSL (needs mkfs.vfat + mcopy):
    python3 build_boot.py <disk.img> <workdir> <out_fat.img>

What changes vs the image currently on the card:
  * kernel cmdline: console=tty0 LAST (so /dev/console is the screen), plus
    clk_ignore_unused, and no redundant root= for the kernel itself.
  * initramfs: every step logs to /dev/tty0, /dev/kmsg and duo-boot.log, with
    sync, so a hang leaves a visible trail on the screen.
  * keeps the same kernel, DTB, boot.img and abl/ folder.
"""
from __future__ import annotations

import gzip
import io
import pathlib
import shutil
import subprocess
import sys

SECTOR = 512
P1_OFF = 2048 * SECTOR

CMDLINE = (
    "console=ttyMSM0,115200n8 console=tty0 "
    "root=LABEL=STORAGE rw rootwait loglevel=7 panic=30 "
    "video=efifb:off gpt clk_ignore_unused "
    "rdinit=/duo-init boot=LABEL=ROCKNIX disk=LABEL=STORAGE "
    "allow_mismatched_32bit_el0"
)

INIT = r"""#!/bin/busybox sh
export PATH=/bin
/bin/busybox --install -s /bin
mount -t proc proc /proc 2>/dev/null
mount -t sysfs sysfs /sys 2>/dev/null
mount -t devtmpfs devtmpfs /dev 2>/dev/null
mkdir -p /dev/pts /dev/shm /run /boot /newroot
mount -t devpts devpts /dev/pts 2>/dev/null
mount -t tmpfs tmpfs /run 2>/dev/null

LOG=/boot/duo-boot.log
BOOT_MOUNTED=0
L() {
  m="duo-init[$(cut -d' ' -f1 /proc/uptime)]: $*"
  echo "$m" > /dev/tty0 2>/dev/null
  echo "$m" > /dev/kmsg 2>/dev/null
  if [ "$BOOT_MOUNTED" = "1" ]; then echo "$m" >> "$LOG" 2>/dev/null; sync; fi
}

L "init running as pid $$"
L "cmdline: $(cat /proc/cmdline)"
L "block devices: $(ls /dev/mmcblk* 2>/dev/null | tr '\n' ' ')"

BOOTDEV="$(blkid -L ROCKNIX 2>/dev/null)"
L "boot device (LABEL=ROCKNIX): ${BOOTDEV:-none}"
if [ -n "$BOOTDEV" ]; then
  if mount -t vfat -o rw "$BOOTDEV" /boot 2>/dev/null; then
    BOOT_MOUNTED=1
    L "boot mounted at /boot"
    L "previous duo-boot.log had $(wc -l < "$LOG" 2>/dev/null || echo 0) lines"
  else
    L "boot mount FAILED"
  fi
fi

rootarg=""
for arg in $(cat /proc/cmdline); do
  case "$arg" in root=*) rootarg="${arg#root=}";; esac
done
L "requested root=$rootarg"

find_root() {
  case "$rootarg" in
    LABEL=*)   blkid -L "${rootarg#LABEL=}" ;;
    UUID=*)    blkid -U "${rootarg#UUID=}" ;;
    PARTUUID=*) blkid -t "PARTUUID=${rootarg#PARTUUID=}" -o device ;;
    /dev/*)    echo "$rootarg" ;;
    *)         echo "" ;;
  esac
}
ROOTDEV="$(find_root)"
L "root by label: ${ROOTDEV:-none}"
if [ -z "$ROOTDEV" ]; then
  ROOTDEV="$(blkid -L STORAGE 2>/dev/null)"
  L "root fallback STORAGE: ${ROOTDEV:-none}"
fi
if [ -z "$ROOTDEV" ]; then
  L "all partitions: $(ls /dev/mmcblk*p* 2>/dev/null | tr '\n' ' ')"
  L "blkid: $(blkid 2>&1 | tr '\n' ' ')"
  L "NO ROOT FOUND - rescue shell on screen"
  exec /bin/sh -i
fi

L "mounting $ROOTDEV"
if ! mount -o rw "$ROOTDEV" /newroot; then
  L "mount FAILED"
  exec /bin/sh -i
fi
L "mounted ok; top level: $(ls /newroot | tr '\n' ' ')"

if [ ! -x /newroot/sbin/init ] && [ ! -x /newroot/usr/lib/systemd/systemd ] && [ ! -x /newroot/lib/systemd/systemd ]; then
  L "NO INIT on $ROOTDEV - rescue shell"
  exec /bin/sh -i
fi

L "init found; switch_root"
mkdir -p /newroot/proc /newroot/sys /newroot/dev /newroot/run
mount --move /proc /newroot/proc 2>/dev/null
mount --move /sys /newroot/sys 2>/dev/null
mount --move /dev /newroot/dev 2>/dev/null
[ "$BOOT_MOUNTED" = "1" ] && umount /boot 2>/dev/null
exec switch_root /newroot /sbin/init
"""


def parse_newc(data: bytes) -> dict[str, tuple[int, bytes]]:
    out: dict[str, tuple[int, bytes]] = {}
    off = 0
    while off + 110 <= len(data):
        if data[off:off + 6] not in (b"070701", b"070702"):
            break
        f = [int(data[off + 6 + 8 * i: off + 6 + 8 * i + 8], 16) for i in range(13)]
        mode, filesize, namesize = f[1], f[6], f[11]
        name_start = off + 110
        name = data[name_start:name_start + namesize - 1].decode(errors="replace")
        data_start = name_start + namesize
        data_start += (-data_start) % 4
        out[name] = (mode, data[data_start:data_start + filesize])
        off = data_start + filesize
        off += (-off) % 4
        if name == "TRAILER!!!":
            break
    return out


def newc(entries: list[tuple[str, int, bytes, int]]) -> bytes:
    out = bytearray()
    for ino, (name, mode, data, rdev) in enumerate(entries, start=1):
        nb = name.encode() + b"\x00"
        fields = [ino, mode, 0, 0, 1, 0, len(data), 0, 0,
                  (rdev >> 8) & 0xFF, rdev & 0xFF, len(nb), 0]
        out += b"070701" + b"".join(f"{v:08x}".encode() for v in fields)
        out += nb
        out += b"\x00" * ((4 - len(out) % 4) % 4)
        out += data
        out += b"\x00" * ((4 - len(out) % 4) % 4)
    out += b"070701" + b"0" * 104 + b"TRAILER!!!\x00"
    out += b"\x00" * ((4 - len(out) % 4) % 4)
    return bytes(out)


def main() -> int:
    img, work, out_fat = (pathlib.Path(a) for a in sys.argv[1:4])

    work.mkdir(parents=True, exist_ok=True)
    for p in work.iterdir():
        shutil.rmtree(p) if p.is_dir() else p.unlink()

    print("extracting partition 1 with mcopy...")
    subprocess.run(["mcopy", "-s", "-n", "-i", f"{img}@@{P1_OFF}", "::*", str(work)], check=True)

    initrd_path = work / "initrd.img"
    raw = initrd_path.read_bytes()
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    members = parse_newc(raw)
    bb = members.get("bin/busybox")
    if not bb or not bb[1]:
        print("ERROR: busybox not found in existing initramfs")
        return 1
    print(f"reusing busybox from existing initramfs ({len(bb[1])} bytes)")

    entries = [
        (".", 0o040755, b"", 0),
        ("bin", 0o040755, b"", 0),
        ("dev", 0o040755, b"", 0),
        ("proc", 0o040755, b"", 0),
        ("sys", 0o040755, b"", 0),
        ("run", 0o040755, b"", 0),
        ("boot", 0o040755, b"", 0),
        ("newroot", 0o040755, b"", 0),
        ("bin/busybox", 0o100755, bb[1], 0),
        ("init", 0o100755, INIT.encode(), 0),
        ("duo-init", 0o100755, INIT.encode(), 0),
    ]
    cpio = newc(entries)
    initrd_path.write_bytes(gzip.compress(cpio, 6, mtime=0))
    print(f"new initramfs: {initrd_path.stat().st_size} bytes")

    (work / "extlinux").mkdir(exist_ok=True)
    (work / "extlinux" / "extlinux.conf").write_text(
        "LABEL DuoLinux\n"
        "  LINUX /KERNEL\n"
        "  FDT /dtbs/qcom/sm6125-retroid-pocket-duo-lite.dtb\n"
        "  INITRD /initrd.img\n"
        f"  APPEND {CMDLINE}\n"
    )
    (work / "loader" / "entries").mkdir(parents=True, exist_ok=True)
    for old in (work / "loader" / "entries").glob("*.conf"):
        if old.name != "duolinux.conf":
            old.unlink()
    (work / "loader" / "entries" / "duolinux.conf").write_text(
        "title      DuoLinux\n"
        "linux      /KERNEL\n"
        "initrd     /initrd.img\n"
        f"options    {CMDLINE}\n"
    )
    print("boot entries rewritten")

    if out_fat.exists():
        out_fat.unlink()
    subprocess.run(["mkfs.vfat", "-F", "32", "-n", "ROCKNIX", "-C", str(out_fat),
                    str(512 * 1024)], check=True, stdout=subprocess.DEVNULL)
    for item in sorted(work.iterdir()):
        subprocess.run(["mcopy", "-s", "-i", str(out_fat), str(item), "::/"], check=True)

    # Put the ABL folder back from the existing image if mcopy skipped it.
    print(f"boot partition image: {out_fat} ({out_fat.stat().st_size} bytes)")
    subprocess.run(["mdir", "-i", str(out_fat), "::/"], check=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
