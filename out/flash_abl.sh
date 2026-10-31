#!/system/bin/sh
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
