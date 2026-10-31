#!/system/bin/sh
# Reports to /data/local/tmp/duo_report.txt (proven writable by the root runner)
# and mirrors the outcome into a settings key as a backstop.
# Flat statements only: no functions, no set -e.
R=/data/local/tmp/duo_report.txt
S=/system/bin/settings
ELF=/sdcard/Download/duolinux/abl_signed-SM6115.elf
IMG=/sdcard/Download/duolinux/duolinux-duol.img.gz

echo "=== DUOLINUX REPORT $(date)" > "$R"
chmod 644 "$R"
echo "id=$(id)" >> "$R"
echo "abl_a_link=$(readlink -f /dev/block/by-name/abl_a)" >> "$R"
echo "elf_present=$([ -f "$ELF" ] && echo yes || echo no)" >> "$R"
echo "img_present=$([ -f "$IMG" ] && echo yes || echo no)" >> "$R"

# Existing backups (from earlier runs) - make them readable so they can be pulled.
chmod 644 /data/local/tmp/abl_a.img /data/local/tmp/abl_b.img 2>/dev/null
echo "--- backups present:" >> "$R"
ls -l /data/local/tmp/abl_a.img /data/local/tmp/abl_b.img >> "$R" 2>&1
echo "backup_a_md5=$(md5sum /data/local/tmp/abl_a.img 2>/dev/null | awk '{print $1}')" >> "$R"
echo "backup_b_md5=$(md5sum /data/local/tmp/abl_b.img 2>/dev/null | awk '{print $1}')" >> "$R"

E=$(md5sum "$ELF" 2>/dev/null | awk '{print $1}')
A1=$(dd if=/dev/block/by-name/abl_a bs=4096 count=130 2>/dev/null | md5sum | awk '{print $1}')
B1=$(dd if=/dev/block/by-name/abl_b bs=4096 count=130 2>/dev/null | md5sum | awk '{print $1}')
echo "--- abl state:" >> "$R"
echo "elf_md5=$E" >> "$R"
echo "current_a_md5=$A1" >> "$R"
echo "current_b_md5=$B1" >> "$R"

if [ "$A1" = "$E" ] && [ "$B1" = "$E" ]; then
  echo "ABL_STATE=already-flashed" >> "$R"
  $S put global duo_state "abl-already-flashed" 2>/dev/null
else
  echo "ABL_STATE=needs-flash" >> "$R"
  # Fresh backups, in case the earlier ones are missing.
  if [ ! -f /data/local/tmp/abl_a.img ]; then
    dd if=/dev/block/by-name/abl_a of=/data/local/tmp/abl_a.img bs=4096 2>/dev/null
  fi
  if [ ! -f /data/local/tmp/abl_b.img ]; then
    dd if=/dev/block/by-name/abl_b of=/data/local/tmp/abl_b.img bs=4096 2>/dev/null
  fi
  chmod 644 /data/local/tmp/abl_a.img /data/local/tmp/abl_b.img 2>/dev/null
  echo "--- flashing:" >> "$R"
  dd if="$ELF" of=/dev/block/by-name/abl_a bs=4096 2>>"$R"
  echo "write_a_rc=$?" >> "$R"
  dd if="$ELF" of=/dev/block/by-name/abl_b bs=4096 2>>"$R"
  echo "write_b_rc=$?" >> "$R"
  sync
  V1=$(dd if=/dev/block/by-name/abl_a bs=4096 count=130 2>/dev/null | md5sum | awk '{print $1}')
  V2=$(dd if=/dev/block/by-name/abl_b bs=4096 count=130 2>/dev/null | md5sum | awk '{print $1}')
  echo "after_a_md5=$V1" >> "$R"
  echo "after_b_md5=$V2" >> "$R"
  if [ "$V1" = "$E" ] && [ "$V2" = "$E" ]; then
    echo "ABL_STATE=flashed-ok" >> "$R"
    $S put global duo_state "abl-flashed-ok" 2>/dev/null
  else
    echo "ABL_STATE=flash-FAILED" >> "$R"
    $S put global duo_state "abl-flash-FAILED" 2>/dev/null
  fi
fi

# Card verification.
echo "--- card:" >> "$R"
echo "card_p1_md5=$(dd if=/dev/block/mmcblk1p1 bs=1048576 2>/dev/null | md5sum | awk '{print $1}')" >> "$R"
echo "image_p1_md5=$(gzip -dc "$IMG" 2>/dev/null | dd bs=1048576 skip=1 count=512 2>/dev/null | md5sum | awk '{print $1}')" >> "$R"
C1=$(grep '^card_p1_md5=' "$R" | cut -d= -f2)
C2=$(grep '^image_p1_md5=' "$R" | cut -d= -f2)
if [ -n "$C1" ] && [ "$C1" = "$C2" ]; then
  echo "CARD=MATCH" >> "$R"
  $S put global duo_state "$($S get global duo_state 2>/dev/null) card-MATCH" 2>/dev/null
else
  echo "CARD=MISMATCH" >> "$R"
fi
echo "=== END $(date)" >> "$R"
chmod 644 "$R"
