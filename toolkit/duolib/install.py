"""Guided local install: SD writer or push-and-run over adb."""

from __future__ import annotations

import gzip
import hashlib
import shutil
import subprocess
import sys
from pathlib import Path

from . import device, util
from .config import CFG, OUT, IMAGE_NAME, CACHE

SD_SCRIPT = r"""#!/system/bin/sh
# DuoLinux SD writer — run with Retroid's "Run script as root".
# Writes only the microSD card. Android / internal storage is never touched.
set -e
BASE=/sdcard/Download/duolinux
IMG="$BASE/duolinux-duol.img.gz"
LOG="$BASE/install_sd.log"
: > "$LOG"
log() { echo "$@"; echo "$@" >> "$LOG"; }
log "DuoLinux installer $(date)"
if [ ! -f "$IMG" ]; then
  log "missing $IMG"
  exit 1
fi

# Find the internal eMMC from the by-name links, so it can never be chosen.
# (The SD slot on this device reports removable=0, so that flag is useless.)
INTERNAL=""
for lp in /dev/block/by-name/*; do
  t=$(readlink -f "$lp" 2>/dev/null)
  case "$t" in
    /dev/block/mmcblk[0-9]*) INTERNAL=$(basename "$t" | sed 's/p[0-9]*$//') ;;
  esac
  if [ -n "$INTERNAL" ]; then break; fi
done
log "internal disk: ${INTERNAL:-unknown} (protected)"

SD=""
FALLBACK=""
for d in /sys/block/mmcblk* /sys/block/sd*; do
  if [ ! -f "$d/size" ]; then continue; fi
  if [ -e "$d/partition" ]; then continue; fi
  n=$(basename "$d")
  case "$n" in *boot*) continue ;; esac
  if [ "$n" = "$INTERNAL" ]; then continue; fi
  if [ ! -b "/dev/block/$n" ]; then continue; fi
  # This shell does 32-bit integer math, so work in MiB (sectors / 2048).
  size_mib=$(( $(cat "$d/size") / 2048 ))
  # The image is 7.5 GiB; cards are sold in decimal GB, so require 16 GiB.
  if [ "$size_mib" -lt 16384 ]; then continue; fi
  # Strong match: the card already carries the DuoLinux layout
  # (partition 1 = 512 MiB FAT, partition 2 = the ~7 GiB rootfs).
  p1=$(cat "/sys/block/$n/${n}p1/size" 2>/dev/null || echo 0)
  p2=$(cat "/sys/block/$n/${n}p2/size" 2>/dev/null || echo 0)
  if [ "$p1" = 1048576 ] && [ "$p2" -ge 6291456 ]; then
    SD="$n"
    break
  fi
  if [ -z "$FALLBACK" ]; then FALLBACK="$n"; fi
done
if [ -z "$SD" ]; then SD="$FALLBACK"; fi

if [ -z "$SD" ]; then
  log "No SD card >= 16 GiB found (internal disk is ${INTERNAL:-unknown})."
  log "Insert the card, choose Cancel if Android offers to format it, then rerun."
  exit 1
fi
if [ "$SD" = "$INTERNAL" ]; then
  log "refusing to write the internal disk"
  exit 1
fi

SIZE_MIB=$(( $(cat "/sys/block/$SD/size") / 2048 ))
log "target: /dev/block/$SD  ($((SIZE_MIB / 1024)) GiB)"
log "this erases the card; internal storage is not touched"

# Unmount anything still mounted from the card.
for m in $(mount | grep "/dev/block/$SD" | awk '{print $3}'); do
  umount "$m" 2>/dev/null || umount -l "$m" 2>/dev/null || true
done

log "writing (this takes 5-15 minutes; do not unplug the card)..."
if gzip -dc "$IMG" | dd of="/dev/block/$SD" bs=4194304 2>>"$LOG"; then
  log "write finished"
else
  log "WRITE FAILED - do not boot this card. Rerun this script."
  exit 1
fi
sync
log "partitions on the card now:"
for p in /sys/block/$SD/${SD}p*; do
  if [ ! -f "$p/size" ]; then continue; fi
  log "  $(basename $p): $(( $(cat $p/size) / 2048 )) MiB"
done
log "Done. Power off, then hold Volume Down while powering on."
log "Set Boot mode = Linux and Boot source = SD Card, then Start."
log "If the stock ABL has no Linux mode, run flash_abl.sh."
"""


def run(disk: str | None = None, *, yes: bool = False, via_adb: bool = False,
        with_abl: bool = False) -> None:
    img = OUT / IMAGE_NAME
    if not img.exists():
        util.die("no image yet. run: duo build")
    util.banner("install")
    if via_adb:
        device.ensure_platform_tools()
        _via_adb(img, yes=yes, with_abl=with_abl)
        return
    if disk:
        if str(disk).isdigit():
            device.flash(img, int(disk), yes=yes)
        else:
            device.flash(img, str(disk), yes=yes)
        return

    disks = device.list_disks()
    candidates = [d for d in disks if str(d.get("BusType", "")).lower() in ("usb", "sd", "mmc")
                  or d.get("tran") in ("usb", "mmc")]
    print()
    for d in candidates:
        num = d.get("Number", d.get("name"))
        name = d.get("FriendlyName", d.get("model", ""))
        size = int(d.get("Size", 0)) / (1 << 30) if d.get("Size") else d.get("size", "?")
        print(f"  disk {num}: {name}  {size:.1f} GiB" if isinstance(size, float) else f"  disk {num}: {name}")
    print()
    if len(candidates) == 1:
        d = candidates[0]
        num = d.get("Number", d.get("name"))
        if not yes and not util.confirm(f"write the image to disk {num}?", default=False):
            return
        device.flash(img, int(num) if str(num).isdigit() else str(num), yes=True)
        return

    # No card reader: offer the adb route automatically.
    try:
        devs = device.adb("devices")
    except SystemExit:
        devs = ""
    if "\tdevice" in devs:
        util.info("No card reader, but the Duo is connected over adb.")
        if yes or util.confirm("push the image and installer to the Duo now?", default=True):
            _via_adb(img, yes=True, with_abl=with_abl)
            return

    util.info("No single removable disk detected.")
    util.info("Options:")
    util.info("  1. Insert the microSD and run: duo install --disk <n>")
    util.info("  2. Without a card reader, push it over USB:")
    util.info("       duo install --via-adb")
    util.info("  3. Write out/%s with Rufus or balenaEtcher." % img.name)
    util.info("")
    util.info("Then test without changing anything: duo boot")


ABL_SCRIPT = r"""#!/system/bin/sh
# DuoLinux ABL installer — SM6115 Duo Lite.
# The only step that touches internal storage. It backs up the stock ABL first,
# and it refuses to run unless the microSD already matches the image.
# The runner hides stdout, so everything is also written to $LOG.
set -e
BASE=/sdcard/Download/duolinux
ELF="$BASE/abl_signed-SM6115.elf"
IMG="$BASE/duolinux-duol.img.gz"
LOG="$BASE/flash_abl.log"
: > "$LOG"
log() { echo "$@"; echo "$@" >> "$LOG"; }
log "DuoLinux ABL installer $(date)"
if [ ! -f "$ELF" ]; then
  log "missing $ELF"
  exit 1
fi

INTERNAL=""
for lp in /dev/block/by-name/*; do
  t=$(readlink -f "$lp" 2>/dev/null)
  case "$t" in
    /dev/block/mmcblk[0-9]*) INTERNAL=$(basename "$t" | sed 's/p[0-9]*$//') ;;
  esac
  if [ -n "$INTERNAL" ]; then break; fi
done
log "internal disk: ${INTERNAL:-unknown} (protected)"

SD=""
for d in /sys/block/mmcblk* /sys/block/sd*; do
  if [ ! -f "$d/size" ]; then continue; fi
  if [ -e "$d/partition" ]; then continue; fi
  n=$(basename "$d")
  case "$n" in *boot*) continue ;; esac
  if [ "$n" = "$INTERNAL" ]; then continue; fi
  if [ ! -b "/dev/block/$n" ]; then continue; fi
  p1=$(cat "/sys/block/$n/${n}p1/size" 2>/dev/null || echo 0)
  if [ "$p1" = 1048576 ]; then SD="$n"; break; fi
done
if [ -z "$SD" ]; then
  log "ABORT: no microSD carrying the DuoLinux boot partition was found."
  exit 1
fi
log "card: /dev/block/$SD"

if [ -f "$IMG" ]; then
  log "checking the card against the image (this takes a minute)..."
  A=$(dd if="/dev/block/${SD}p1" bs=1048576 2>/dev/null | md5sum | awk '{print $1}')
  B=$(gzip -dc "$IMG" 2>/dev/null | dd bs=1048576 skip=1 count=512 2>/dev/null | md5sum | awk '{print $1}')
  log "card boot partition:  $A"
  log "image boot partition: $B"
  if [ -z "$A" ] || [ "$A" != "$B" ]; then
    log "ABORT: the card does not match the image. Nothing was written."
    log "Rerun install_sd.sh, then run this script again."
    exit 1
  fi
  log "card matches the image"
else
  log "WARNING: $IMG not found; skipping the card check"
fi

log "backing up the stock ABL..."
dd if=/dev/block/by-name/abl_a of="$BASE/abl_a.img" bs=4096 2>>"$LOG"
dd if=/dev/block/by-name/abl_b of="$BASE/abl_b.img" bs=4096 2>>"$LOG"
sync
log "backups:"
ls -l "$BASE/abl_a.img" "$BASE/abl_b.img" >> "$LOG" 2>&1

log "flashing the ROCKNIX ABL (SM6115)..."
dd if="$ELF" of=/dev/block/by-name/abl_a bs=4096 2>>"$LOG"
dd if="$ELF" of=/dev/block/by-name/abl_b bs=4096 2>>"$LOG"
sync
log "DONE. Power off, then hold Volume Down while powering on."
log "Set Boot mode = Linux and Boot source = SD Card."
"""


def _via_adb(img: Path, *, yes: bool, with_abl: bool = False) -> None:
    device.ensure_platform_tools()
    devices = device.adb("devices")
    if "\tdevice" not in devices:
        util.die("no adb device. Enable USB debugging on the Duo and accept the prompt.")
    if not yes and not util.confirm(
        "Push the image, SD writer" + (" and ABL installer" if with_abl else "") +
        " to the Duo? " + (
            "flash_abl.sh backs up abl_a/abl_b before writing." if with_abl
            else "Android is not modified; the script only writes the microSD card."
        ), default=True
    ):
        return

    gz = img.with_suffix(img.suffix + ".gz")
    if not gz.exists() or gz.stat().st_mtime < img.stat().st_mtime:
        util.info(f"compressing {img.name} (one time)")
        with img.open("rb") as src, gzip.open(gz, "wb", compresslevel=1) as dst:
            shutil.copyfileobj(src, dst, 8 << 20)
    util.ok(f"{gz.name} {util.human(gz.stat().st_size)}")

    remote = "/sdcard/Download/duolinux"
    device.adb("shell", "mkdir", "-p", remote)
    util.info("pushing image (this is the slow part)")
    device.adb("push", str(gz), f"{remote}/", check=True, quiet=False)
    if img.with_name("SHA256SUMS").exists():
        device.adb("push", str(img.with_name("SHA256SUMS")), f"{remote}/", check=True, quiet=False)

    script = OUT / "install_sd.sh"
    script.write_text(SD_SCRIPT)
    device.adb("push", str(script), f"{remote}/install_sd.sh", check=True, quiet=False)

    abl_note = ""
    if with_abl:
        if not CFG.is_lite:
            util.die("--with-abl is only wired for the Duo Lite (SM6115)")
        elf = OUT / "abl_signed-SM6115.elf"
        if not elf.exists():
            elf = CACHE / "rocknix/extract/3rdparty/bootloader/openabl/abl_signed-SM6115.elf"
        if not elf.exists():
            util.die("SM6115 ABL not fetched; run: duo fetch")
        device.adb("push", str(elf), f"{remote}/abl_signed-SM6115.elf", check=True, quiet=False)
        abl = OUT / "flash_abl.sh"
        abl.write_text(ABL_SCRIPT)
        device.adb("push", str(abl), f"{remote}/flash_abl.sh", check=True, quiet=False)
        abl_note = "flash_abl.sh (ABL, after the SD install)"

    util.banner("one tap left")
    util.info("On the Duo:")
    util.info("  Settings -> Handheld Settings -> Advanced -> Run script as root")
    util.info(f"  choose Download/duolinux/install_sd.sh")
    if abl_note:
        util.info(f"  then choose Download/duolinux/{abl_note}")
        util.info("")
        util.info("The ABL script backs up abl_a/abl_b to the same folder before writing.")
        util.info("Copy those two files off the device.")
    util.info("")
    util.info("It finds the removable card by itself and refuses anything under 16 GiB.")
    util.info("Android and internal storage are untouched by the SD script.")
