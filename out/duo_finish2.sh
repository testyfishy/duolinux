#!/system/bin/sh
# DuoLinux finaliser — SM6115 Duo Lite.
# Reports ONLY through logcat (`log -t DUOLINUX`), because root cannot write to
# /sdcard and its mount namespace may hide other writable paths.
# Read the report on the PC with:  adb logcat -d -s DUOLINUX
#
# Safety: refuses to touch abl_a/abl_b unless the microSD matches the image.
BASE=/sdcard/Download/duolinux
IMG="$BASE/duolinux-duol.img.gz"
ELF="$BASE/abl_signed-SM6115.elf"
ELF_BLOCKS=130
say() { log -t DUOLINUX "$*"; }

say "==== duo-finish2 start $(date)"
say "id=$(id)"
say "internal_by_name=$(readlink -f /dev/block/by-name/abl_a)"

# Where can root actually write?
BK=""
for p in /data/local/tmp /cache /data; do
  if ( : > "$p/duo_probe.txt" ) 2>/dev/null; then
    say "WRITE OK $p"
    [ -z "$BK" ] && BK="$p"
    rm -f "$p/duo_probe.txt"
  else
    say "WRITE FAIL $p"
  fi
done
for p in /dev /sdcard/Download /sdcard/Download/duolinux; do
  if ( : > "$p/duo_probe.txt" ) 2>/dev/null; then
    say "WRITE OK $p"
    rm -f "$p/duo_probe.txt"
  else
    say "WRITE FAIL $p"
  fi
done
say "backup_dir=${BK:-none}"

if [ ! -f "$ELF" ]; then
  say "RESULT=missing-elf"
  exit 1
fi

# Internal eMMC, so it can never be chosen as the card.
INTERNAL=""
for lp in /dev/block/by-name/*; do
  t=$(readlink -f "$lp" 2>/dev/null)
  case "$t" in
    /dev/block/mmcblk[0-9]*) INTERNAL=$(basename "$t" | sed 's/p[0-9]*$//') ;;
  esac
  if [ -n "$INTERNAL" ]; then break; fi
done
say "internal=$INTERNAL"

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
say "card=$SD"
if [ -z "$SD" ]; then
  say "RESULT=no-card"
  exit 1
fi

if [ -f "$IMG" ]; then
  say "hashing the 512 MiB boot partition (about a minute)..."
  A=$(dd if="/dev/block/${SD}p1" bs=1048576 2>/dev/null | md5sum | awk '{print $1}')
  B=$(gzip -dc "$IMG" 2>/dev/null | dd bs=1048576 skip=1 count=512 2>/dev/null | md5sum | awk '{print $1}')
  say "card_p1_md5=$A"
  say "image_p1_md5=$B"
  if [ -z "$A" ] || [ "$A" != "$B" ]; then
    say "RESULT=card-mismatch"
    exit 1
  fi
  say "card matches image"
else
  say "RESULT=no-image-file"
  exit 1
fi

say "stock ABL:"
say "  abl_a_md5=$(dd if=/dev/block/by-name/abl_a bs=4096 count=$ELF_BLOCKS 2>/dev/null | md5sum | awk '{print $1}')"
say "  abl_b_md5=$(dd if=/dev/block/by-name/abl_b bs=4096 count=$ELF_BLOCKS 2>/dev/null | md5sum | awk '{print $1}')"
say "  elf_md5=$(md5sum "$ELF" | awk '{print $1}')"

if [ -n "$BK" ]; then
  say "saving ABL backups to $BK"
  if dd if=/dev/block/by-name/abl_a of="$BK/abl_a.img" bs=4096 2>/dev/null; then
    say "backup_a=ok"
  else
    say "backup_a=FAILED"
  fi
  if dd if=/dev/block/by-name/abl_b of="$BK/abl_b.img" bs=4096 2>/dev/null; then
    say "backup_b=ok"
  else
    say "backup_b=FAILED"
  fi
  chmod 644 "$BK/abl_a.img" "$BK/abl_b.img" 2>/dev/null
  say "  $(ls -l "$BK/abl_a.img" 2>&1 | tr -s ' ')"
  say "  $(ls -l "$BK/abl_b.img" 2>&1 | tr -s ' ')"
else
  say "WARNING: nowhere to save an ABL backup; flashing anyway is not offered here"
  say "RESULT=no-backup-storage"
  exit 1
fi

E=$(md5sum "$ELF" | awk '{print $1}')
A1=$(md5sum "$BK/abl_a.img" 2>/dev/null | awk '{print $1}')
B1=$(md5sum "$BK/abl_b.img" 2>/dev/null | awk '{print $1}')
if [ "$A1" = "$E" ] && [ "$B1" = "$E" ]; then
  say "RESULT=abl-already-flashed"
  exit 0
fi

say "flashing ROCKNIX ABL to abl_a and abl_b"
dd if="$ELF" of=/dev/block/by-name/abl_a bs=4096 2>/dev/null
dd if="$ELF" of=/dev/block/by-name/abl_b bs=4096 2>/dev/null
sync
V1=$(dd if=/dev/block/by-name/abl_a bs=4096 count=$ELF_BLOCKS 2>/dev/null | md5sum | awk '{print $1}')
V2=$(dd if=/dev/block/by-name/abl_b bs=4096 count=$ELF_BLOCKS 2>/dev/null | md5sum | awk '{print $1}')
say "verify_a=$V1"
say "verify_b=$V2"
if [ "$V1" = "$E" ] && [ "$V2" = "$E" ]; then
  say "RESULT=abl-flashed-ok"
else
  say "RESULT=abl-flash-FAILED"
fi
say "==== done $(date)"
