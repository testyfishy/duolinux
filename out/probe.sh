#!/system/bin/sh
# Diagnostic only: writes nothing outside its own report, and never writes to
# any block device (the card tests are read-only / zero-length).
OUT=/dev/probe_report.txt
{
  echo "== probe start"
  date
  id
  echo "--- relevant mounts"
  mount | grep -E " /data | /dev | /sdcard | /storage" | head -20
  echo "--- write tests"
  for p in /data/local/tmp /dev /cache /data /sdcard/Download /sdcard/Download/duolinux; do
    if ( : > "$p/probe_test.txt" ) 2>/dev/null; then
      echo "OK   $p"
      rm -f "$p/probe_test.txt"
    else
      echo "FAIL $p"
    fi
  done
  echo "--- card read test"
  dd if=/dev/block/mmcblk1p1 bs=4096 count=1 2>&1 | md5sum
  echo "--- image FAT boot sector md5 (for comparison)"
  gzip -dc /sdcard/Download/duolinux/duolinux-duol.img.gz 2>/dev/null | dd bs=4096 skip=256 count=1 2>/dev/null | md5sum
  echo "--- card open-for-write test (writes zero bytes)"
  dd if=/dev/zero of=/dev/block/mmcblk1 bs=4096 count=0 2>&1
  echo "--- abl read test"
  dd if=/dev/block/by-name/abl_a bs=4096 count=1 2>&1 | md5sum
  echo "== probe end"
} > "$OUT" 2>&1
