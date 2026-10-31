#!/system/bin/sh
# DuoLinux finaliser — SM6115 Duo Lite.
#
# The root runner hides stdout, cannot write /sdcard, and its mount namespace
# hides other paths, so the report goes into the global settings DB, which can
# be read from the PC with:  adb shell settings get global duo_log
#
# Safety: never touches abl_a/abl_b unless the microSD matches the image.
BASE=/sdcard/Download/duolinux
IMG="$BASE/duolinux-duol.img.gz"
ELF="$BASE/abl_signed-SM6115.elf"
ELF_BLOCKS=130

say() {
  old=$(settings get global duo_log 2>/dev/null)
  case "$old" in null|"") old="" ;; esac
  if [ -n "$old" ]; then
    settings put global duo_log "$old ;; $*" 2>/dev/null
  else
    settings put global duo_log "$*" 2>/dev/null
  fi
}

settings put global duo_log "begin $(date)" 2>/dev/null
say "id=$(id)"
say "abl_a_link=$(readlink -f /dev/block/by-name/abl_a)"
say "data_mount=$(mount | awk '\$2==\"/data\"{print \$1,\$4}')"

# Find a writable place for the ABL backup.
BK=""
for p in /data/local/tmp /cache /data; do
  if ( : > "$p/duo_probe.txt" ) 2>/dev/null; then
    say "WRITE_OK $p"
    [ -z "$BK" ] && BK="$p"
    rm -f "$p/duo_probe.txt"
  else
    say "WRITE_FAIL $p"
  fi
done
say "backup_dir=${BK:-none}"

if [ ! -f "$ELF" ]; then
  say "RESULT=missing-elf"
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

if [ ! -f "$IMG" ]; then
  say "RESULT=no-image-file"
  exit 1
fi

say "hashing card (about a minute)"
A=$(dd if="/dev/block/${SD}p1" bs=1048576 2>/dev/null | md5sum | awk '{print $1}')
B=$(gzip -dc "$IMG" 2>/dev/null | dd bs=1048576 skip=1 count=512 2>/dev/null | md5sum | awk '{print $1}')
say "card_p1=$A"
say "image_p1=$B"
if [ -z "$A" ] || [ "$A" != "$B" ]; then
  say "RESULT=card-mismatch"
  exit 1
fi
say "card matches image"

E=$(md5sum "$ELF" | awk '{print $1}')
say "elf_md5=$E"
say "stock_a=$(dd if=/dev/block/by-name/abl_a bs=4096 count=$ELF_BLOCKS 2>/dev/null | md5sum | awk '{print $1}')"
say "stock_b=$(dd if=/dev/block/by-name/abl_b bs=4096 count=$ELF_BLOCKS 2>/dev/null | md5sum | awk '{print $1}')"

if [ -z "$BK" ]; then
  say "RESULT=no-backup-storage"
  exit 1
fi

dd if=/dev/block/by-name/abl_a of="$BK/abl_a.img" bs=4096 2>/dev/null && say "backup_a=ok" || say "backup_a=FAILED"
dd if=/dev/block/by-name/abl_b of="$BK/abl_b.img" bs=4096 2>/dev/null && say "backup_b=ok" || say "backup_b=FAILED"
chmod 644 "$BK/abl_a.img" "$BK/abl_b.img" 2>/dev/null
say "sizes=$(ls -l "$BK/abl_a.img" "$BK/abl_b.img" 2>/dev/null | awk '{print $5}' | tr '\n' ',')"

A1=$(md5sum "$BK/abl_a.img" 2>/dev/null | awk '{print $1}')
B1=$(md5sum "$BK/abl_b.img" 2>/dev/null | awk '{print $1}')
if [ "$A1" = "$E" ] && [ "$B1" = "$E" ]; then
  say "RESULT=abl-already-flashed"
  exit 0
fi

say "flashing ABL to both slots"
dd if="$ELF" of=/dev/block/by-name/abl_a bs=4096 2>/dev/null && say "write_a=ok" || say "write_a=FAILED"
dd if="$ELF" of=/dev/block/by-name/abl_b bs=4096 2>/dev/null && say "write_b=ok" || say "write_b=FAILED"
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
say "end $(date)"
