#!/system/bin/sh
# Flat script: one `settings put` per result, no functions, no nesting.
# Read the results on the PC with:
#   adb shell settings list global | grep duo_
S=/system/bin/settings
ELF=/sdcard/Download/duolinux/abl_signed-SM6115.elf
IMG=/sdcard/Download/duolinux/duolinux-duol.img.gz

$S put global duo_1 "started"
ID=$(id)
$S put global duo_2 "id=$ID"
LINK=$(readlink -f /dev/block/by-name/abl_a)
$S put global duo_3 "abl_a=$LINK"

if [ ! -f "$ELF" ]; then
  $S put global duo_result "no-elf"
  exit 1
fi
$S put global duo_4 "elf_present=1"

dd if=/dev/block/by-name/abl_a of=/data/local/tmp/abl_a.img bs=4096 2>/dev/null
$S put global duo_5 "backup_a_rc=$?"
dd if=/dev/block/by-name/abl_b of=/data/local/tmp/abl_b.img bs=4096 2>/dev/null
$S put global duo_6 "backup_b_rc=$?"
SZ=$(ls -l /data/local/tmp/abl_a.img 2>/dev/null | awk '{print $5}')
$S put global duo_7 "backup_a_size=$SZ"

E=$(md5sum "$ELF" | awk '{print $1}')
A1=$(dd if=/dev/block/by-name/abl_a bs=4096 count=130 2>/dev/null | md5sum | awk '{print $1}')
$S put global duo_8 "elf_md5=$E"
$S put global duo_9 "current_a_md5=$A1"

if [ "$A1" = "$E" ]; then
  $S put global duo_result "already-flashed"
else
  dd if="$ELF" of=/dev/block/by-name/abl_a bs=4096 2>/dev/null
  $S put global duo_10 "write_a_rc=$?"
  dd if="$ELF" of=/dev/block/by-name/abl_b bs=4096 2>/dev/null
  $S put global duo_11 "write_b_rc=$?"
  sync
  V1=$(dd if=/dev/block/by-name/abl_a bs=4096 count=130 2>/dev/null | md5sum | awk '{print $1}')
  V2=$(dd if=/dev/block/by-name/abl_b bs=4096 count=130 2>/dev/null | md5sum | awk '{print $1}')
  $S put global duo_12 "after_a_md5=$V1"
  $S put global duo_13 "after_b_md5=$V2"
  if [ "$V1" = "$E" ] && [ "$V2" = "$E" ]; then
    $S put global duo_result "flashed-ok"
  else
    $S put global duo_result "flash-FAILED"
  fi
fi

C1=$(dd if=/dev/block/mmcblk1p1 bs=1048576 2>/dev/null | md5sum | awk '{print $1}')
$S put global duo_14 "card_p1_md5=$C1"
C2=$(gzip -dc "$IMG" 2>/dev/null | dd bs=1048576 skip=1 count=512 2>/dev/null | md5sum | awk '{print $1}')
$S put global duo_15 "image_p1_md5=$C2"
if [ "$C1" = "$C2" ]; then
  $S put global duo_card "MATCH"
else
  $S put global duo_card "MISMATCH"
fi
