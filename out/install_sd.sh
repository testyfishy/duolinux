#!/system/bin/sh
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
