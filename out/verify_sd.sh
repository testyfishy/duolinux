#!/system/bin/sh
# DuoLinux SD verifier — run with Retroid's "Run script as root".
# Read-only: writes nothing but its own log. The runner hides stdout, so
# everything also goes to $LOG, which can be read over adb.
BASE=/sdcard/Download/duolinux
IMG="$BASE/duolinux-duol.img.gz"
MNT=/data/local/tmp/sdchk
LOG="$BASE/verify_sd.log"
: > "$LOG"
log() { echo "$@"; echo "$@" >> "$LOG"; }
log "DuoLinux SD verifier $(date)"

if [ ! -f "$IMG" ]; then
  log "missing $IMG"
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
  log "No card with a 512 MiB first partition found."
  exit 1
fi
log "card: /dev/block/$SD"

mkdir -p "$MNT"
if mount -t vfat -o ro "/dev/block/${SD}p1" "$MNT" 2>/dev/null; then
  log "--- boot files on the card:"
  ls -l "$MNT" >> "$LOG" 2>&1
  log "--- abl folder:"
  ls -l "$MNT/abl" >> "$LOG" 2>&1
  umount "$MNT" 2>/dev/null
else
  log "could not mount the FAT partition (harmless; the hash check is what matters)"
fi

log "--- comparing the 512 MiB boot partition with the image..."
A=$(dd if="/dev/block/${SD}p1" bs=1048576 2>/dev/null | md5sum | awk '{print $1}')
B=$(gzip -dc "$IMG" 2>/dev/null | dd bs=1048576 skip=1 count=512 2>/dev/null | md5sum | awk '{print $1}')
log "card:  $A"
log "image: $B"
if [ -n "$A" ] && [ "$A" = "$B" ]; then
  log "MATCH - the card's boot partition is identical to the image."
else
  log "MISMATCH - do not boot this card; rerun install_sd.sh."
fi
