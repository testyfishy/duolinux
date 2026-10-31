#!/usr/bin/env python3
"""Patch the existing 512 MiB ROCKNIX boot partition in place (no mkfs).

Run inside WSL (needs mcopy/mtype):
    python3 build_boot2.py <disk.img> <workdir> <out_p1.img>

Replaces only three files inside the original FAT: initrd.img,
extlinux/extlinux.conf and loader/entries/duolinux.conf.  The volume serial,
cluster layout and every other file (kernel, dtbs, boot.img, abl/) are kept
byte-for-byte, so the ABL still finds exactly what it found before.
"""
from __future__ import annotations

import gzip
import pathlib
import shutil
import subprocess
import sys

SECTOR = 512
P1_OFF = 2048 * SECTOR
P1_SIZE = 512 * 1024 * 1024

CMDLINE = (
    "console=tty0 root=LABEL=STORAGE rw rootwait loglevel=7 panic=30 "
    "video=efifb:off gpt clk_ignore_unused rdinit=/duo-init "
    "boot=LABEL=ROCKNIX disk=LABEL=STORAGE allow_mismatched_32bit_el0 "
    "systemd.show_status=1"
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
exec </dev/tty1 >/dev/tty1 2>&1

LOG=/boot/duo-boot.log
BOOTMOUNTED=0
L() {
  m="duo-init: $*"
  echo "$m"
  echo "$m" > /dev/kmsg 2>/dev/null
  if [ "$BOOTMOUNTED" = "1" ]; then echo "$m" >> "$LOG" 2>/dev/null; sync; fi
}

L "==== start, kernel $(uname -r), pid $$"
L "cmdline: $(cat /proc/cmdline)"
L "disks: $(ls /dev/mmcblk* 2>/dev/null | tr '\n' ' ')"

BOOTDEV=""
for i in 1 2 3 4 5 6 7 8 9 10; do
  BOOTDEV="$(findfs LABEL=ROCKNIX 2>/dev/null)"
  [ -n "$BOOTDEV" ] && break
  BOOTDEV="$(blkid 2>/dev/null | grep -i ROCKNIX | cut -d: -f1)"
  [ -n "$BOOTDEV" ] && break
  sleep 1
done
L "boot partition: ${BOOTDEV:-not found}"
if [ -n "$BOOTDEV" ] && mount -t vfat -o rw "$BOOTDEV" /boot 2>/dev/null; then
  BOOTMOUNTED=1
  L "boot mounted"
fi

ROOTDEV=""
for i in $(seq 1 30); do
  ROOTDEV="$(findfs LABEL=STORAGE 2>/dev/null)"
  [ -n "$ROOTDEV" ] && break
  ROOTDEV="$(blkid 2>/dev/null | grep -i STORAGE | cut -d: -f1)"
  [ -n "$ROOTDEV" ] && break
  [ $i = 1 ] && L "waiting for STORAGE..."
  sleep 1
done
L "root partition: ${ROOTDEV:-NOT FOUND after 30s}"
if [ -z "$ROOTDEV" ]; then
  L "blkid sees: $(blkid 2>/dev/null | tr '\n' ' ')"
  L "partitions: $(ls /dev/mmcblk*p* 2>/dev/null | tr '\n' ' ')"
  L "FAILED: no root, sleeping so the screen stays readable"
  sleep 99999
fi

L "mounting $ROOTDEV as ext4"
if ! mount -t ext4 -o rw "$ROOTDEV" /newroot; then
  L "FAILED: cannot mount $ROOTDEV"
  sleep 99999
fi
L "rootfs top level: $(ls /newroot 2>/dev/null | tr '\n' ' ')"
L "kernel modules dir present: $([ -d /newroot/lib/modules/$(uname -r) ] && echo YES || echo NO)"
L "----- /etc/fstab -----"
while read -r line; do L "fstab| $line"; done < /newroot/etc/fstab 2>/dev/null
L "----------------------"

if [ ! -x /newroot/sbin/init ] && [ ! -x /newroot/usr/lib/systemd/systemd ] && [ ! -x /newroot/lib/systemd/systemd ]; then
  L "FAILED: no init found on the rootfs"
  sleep 99999
fi

L "OK - pausing 15s so the screen can be photographed"
sleep 15

# Apply the modification overlay from the boot partition, so future changes are
# a small FAT write instead of rewriting the whole root filesystem.
OV=/boot/duolinux-overlay
if [ -d "$OV" ]; then
  L "applying overlay"
  cp -a "$OV/." /newroot/ 2>/dev/null
  chmod 755 /newroot/usr/local/bin/duo-* 2>/dev/null
  chmod 644 /newroot/etc/systemd/system/duo-*.service 2>/dev/null
  chmod 755 /newroot/usr/local/bin/duo-usb-gadget /newroot/usr/local/bin/duo-diag 2>/dev/null
  mkdir -p /newroot/home/duo/.ssh
  chmod 700 /newroot/home/duo/.ssh 2>/dev/null
  chmod 600 /newroot/home/duo/.ssh/authorized_keys 2>/dev/null
  chown -R 1000:1000 /newroot/home/duo/.ssh 2>/dev/null
  mkdir -p /newroot/etc/systemd/system/multi-user.target.wants
  if [ -f "$OV/ENABLE" ]; then
    for u in $(cat "$OV/ENABLE"); do
      tgt=""
      if [ -f "/newroot/etc/systemd/system/$u" ]; then tgt="/etc/systemd/system/$u"; fi
      if [ -z "$tgt" ] && [ -f "/newroot/usr/lib/systemd/system/$u" ]; then tgt="/usr/lib/systemd/system/$u"; fi
      if [ -z "$tgt" ] && [ -f "/newroot/lib/systemd/system/$u" ]; then tgt="/lib/systemd/system/$u"; fi
      if [ -n "$tgt" ]; then
        ln -sf "$tgt" "/newroot/etc/systemd/system/multi-user.target.wants/$u" 2>/dev/null
      fi
      L "enable $u -> ${tgt:-not-found}"
    done
  fi
  L "overlay applied"
else
  L "no overlay directory on the boot partition"
fi
mkdir -p /newroot/proc /newroot/sys /newroot/dev /newroot/run
mount --move /proc /newroot/proc 2>/dev/null
mount --move /sys /newroot/sys 2>/dev/null
mount --move /dev /newroot/dev 2>/dev/null
[ "$BOOTMOUNTED" = "1" ] && umount /boot 2>/dev/null
L "switch_root now"
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
        n0 = off + 110
        name = data[n0:n0 + namesize - 1].decode(errors="replace")
        d0 = n0 + namesize
        d0 += (-d0) % 4
        out[name] = (mode, data[d0:d0 + filesize])
        off = d0 + filesize
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
    img, work, out_p1 = (pathlib.Path(a) for a in sys.argv[1:4])
    work.mkdir(parents=True, exist_ok=True)
    for p in work.iterdir():
        shutil.rmtree(p) if p.is_dir() else p.unlink()

    # 1. Copy p1 out of the disk image, untouched.
    print("copying partition 1 out of the image...")
    with img.open("rb") as f:
        f.seek(P1_OFF)
        p1data = f.read(P1_SIZE)
    if len(p1data) != P1_SIZE:
        print("ERROR: short read")
        return 1
    out_p1.write_bytes(p1data)
    print(f"p1 copy: {out_p1} ({out_p1.stat().st_size} bytes)")

    # 2. Pull the existing initrd to reuse busybox.
    subprocess.run(["mcopy", "-o", "-n", "-i", str(out_p1), "::/initrd.img", str(work / "old-initrd.img")], check=True)
    raw = (work / "old-initrd.img").read_bytes()
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    members = parse_newc(raw)
    bb = members.get("bin/busybox")
    if not bb or not bb[1]:
        print("ERROR: busybox missing from old initramfs")
        return 1
    print(f"busybox: {len(bb[1])} bytes")

    # 3. Build the new initramfs (same script at /init and /duo-init,
    #    plus a static /dev/console so PID 1 always has an fd).
    entries = [
        (".", 0o040755, b"", 0),
        ("bin", 0o040755, b"", 0),
        ("dev", 0o040755, b"", 0),
        ("proc", 0o040755, b"", 0),
        ("sys", 0o040755, b"", 0),
        ("run", 0o040755, b"", 0),
        ("boot", 0o040755, b"", 0),
        ("newroot", 0o040755, b"", 0),
        ("dev/console", 0o020600, b"", 0x0501),
        ("bin/busybox", 0o100755, bb[1], 0),
        ("init", 0o100755, INIT.encode(), 0),
        ("duo-init", 0o100755, INIT.encode(), 0),
    ]
    new_initrd = gzip.compress(newc(entries), 6, mtime=0)
    (work / "initrd.img").write_bytes(new_initrd)
    print(f"new initramfs: {len(new_initrd)} bytes")

    # 4. Boot entries.
    (work / "extlinux.conf").write_text(
        "LABEL DuoLinux\n"
        "  LINUX /KERNEL\n"
        "  FDT /dtbs/qcom/sm6125-retroid-pocket-duo-lite.dtb\n"
        "  INITRD /initrd.img\n"
        f"  APPEND {CMDLINE}\n"
    )
    (work / "duolinux.conf").write_text(
        "title      DuoLinux\n"
        "linux      /KERNEL\n"
        "initrd     /initrd.img\n"
        f"options    {CMDLINE}\n"
    )

    # 5. Overwrite the three files inside the ORIGINAL p1 image.
    for src, dst in (
        (work / "initrd.img", "::/initrd.img"),
        (work / "extlinux.conf", "::/extlinux/extlinux.conf"),
        (work / "duolinux.conf", "::/loader/entries/duolinux.conf"),
    ):
        subprocess.run(["mcopy", "-o", "-i", str(out_p1), str(src), dst], check=True)
        print(f"wrote {dst}")

    # 6. Copy the modification overlay into the boot partition.
    overlay = pathlib.Path(__file__).resolve().parent.parent / "out" / "overlay"
    if overlay.is_dir():
        subprocess.run(["mmd", "-i", str(out_p1), "::/duolinux-overlay"], check=False)
        for item in sorted(overlay.iterdir()):
            subprocess.run(["mcopy", "-s", "-o", "-i", str(out_p1), str(item),
                            "::/duolinux-overlay/"], check=True)
        print("overlay copied into ::/duolinux-overlay")

    print("--- verify:")
    subprocess.run(["mdir", "-i", str(out_p1), "::/"], check=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
