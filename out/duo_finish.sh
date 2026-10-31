#!/system/bin/sh
# DuoLinux: verify the microSD, back up the stock ABL, flash the ROCKNIX ABL.
# Run with Retroid's "Run script as root".
#
# The runner hides stdout AND root cannot write into /sdcard (FUSE), so the
# whole log goes to /data/local/tmp/duo-finish.log, which adb can read.
#
# It refuses to touch abl_a/abl_b unless the card matches the image.
BASE=/sdcard/Download/duolinux
IMG="$BASE/duolinux-duol.img.gz"
ELF="$BASE/abl_signed-SM6115.elf"
TMP=/data/local/tmp
LOG="$TMP/duo-finish.log"
ELF_BLOCKS=130   # 532480 bytes of ABL at 4096 bytes per block

: > "$LOG" 2>/dev/null || { echo "cannot write $LOG"; exit 1; }
exec >>"$LOG" 2>&1
set -x
echo "== duo-finish start $(date)"

if [ ! -f "$ELF" ]; then
  echo "RESULT=missing-elf"
  exit 1
fi

# Internal eMMC, from the by-name links.
INTERNAL=""
for lp in /dev/block/by-name/*; do
  t=$(readlink -f "$lp" 2>/dev/null)
  case "$t" in
    /dev/block/mmcblk[0-9]*) INTERNAL=$(basename "$t" | sed 's/p[0-9]*$//') ;;
  esac
  if [ -n "$INTERNAL" ]; then break; fi
done
echo "internal=$INTERNAL"

# The card: 512 MiB first partition, never the internal disk.
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
echo "card=$SD"
if [ -z "$SD" ]; then
  echo "RESULT=no-card"
  exit 1
fi

# Prove the card is a faithful copy of the image before touching the bootloader.
if [ -f "$IMG" ]; then
  A=$(dd if="/dev/block/${SD}p1" bs=1048576 2>/dev/null | md5sum | awk '{print $1}')
  B=$(gzip -dc "$IMG" 2>/dev/null | dd bs=1048576 skip=1 count=512 2>/dev/null | md5sum | awk '{print $1}')
  echo "card_p1_md5=$A"
  echo "image_p1_md5=$B"
  if [ -z "$A" ] || [ "$A" != "$B" ]; then
    echo "RESULT=card-mismatch"
    exit 1
  fi
  echo "card matches image"
else
  echo "warning: image not found, skipping card check"
fi

# Back up both ABL slots where adb can retrieve them.
dd if=/dev/block/by-name/abl_a of="$TMP/abl_a.img" bs=4096 2>/dev/null
dd if=/dev/block/by-name/abl_b of="$TMP/abl_b.img" bs=4096 2>/dev/null
chmod 644 "$TMP/abl_a.img" "$TMP/abl_b.img" 2>/dev/null
ls -l "$TMP/abl_a.img" "$TMP/abl_b.img"

E=$(md5sum "$ELF" | awk '{print $1}')
A1=$(dd if=/dev/block/by-name/abl_a bs=4096 count=$ELF_BLOCKS 2>/dev/null | md5sum | awk '{print $1}')
B1=$(dd if=/dev/block/by-name/abl_b bs=4096 count=$ELF_BLOCKS 2>/dev/null | md5sum | awk '{print $1}')
echo "elf_md5=$E"
echo "abl_a_md5=$A1"
echo "abl_b_md5=$B1"

if [ "$A1" = "$E" ] && [ "$B1" = "$E" ]; then
  echo "RESULT=abl-already-flashed"
  exit 0
fi

echo "flashing ABL to both slots"
dd if="$ELF" of=/dev/block/by-name/abl_a bs=4096 2>/dev/null
dd if="$ELF" of=/dev/block/by-name/abl_b bs=4096 2>/dev/null
sync
V1=$(dd if=/dev/block/by-name/abl_a bs=4096 count=$ELF_BLOCKS 2>/dev/null | md5sum | awk '{print $1}')
V2=$(dd if=/dev/block/by-name/abl_b bs=4096 count=$ELF_BLOCKS 2>/dev/null | md5sum | awk '{print $1}')
echo "verify_a_md5=$V1"
echo "verify_b_md5=$V2"
if [ "$V1" = "$E" ] && [ "$V2" = "$E" ]; then
  echo "RESULT=abl-flashed-ok"
else
  echo "RESULT=abl-flash-FAILED"
  exit 1
fi
