#!/system/bin/sh
# Fix the microSD boot config: make the SCREEN the console, and add
# clk_ignore_unused.  Only the changed 512-byte sectors are written.
#
# The "Run script as root" runner can kill its child after ~1 second, so this
# re-launches itself detached and returns immediately.
if [ "$1" != "detached" ]; then
  setsid sh "$0" detached >/dev/null 2>&1 &
  echo "started detached"
  exit 0
fi
sleep 1
B=/dev/block/mmcblk1
set -e
dd if=/data/local/tmp/duo-patch.bin of=$B bs=512 skip=0 seek=93563 count=1 conv=notrunc 2>/dev/null
dd if=/data/local/tmp/duo-patch.bin of=$B bs=512 skip=512 seek=104896 count=1 conv=notrunc 2>/dev/null
dd if=/data/local/tmp/duo-patch.bin of=$B bs=512 skip=1024 seek=161475 count=1 conv=notrunc 2>/dev/null
dd if=/data/local/tmp/duo-patch.bin of=$B bs=512 skip=1536 seek=175192 count=1 conv=notrunc 2>/dev/null
dd if=/data/local/tmp/duo-patch.bin of=$B bs=512 skip=2048 seek=177208 count=1 conv=notrunc 2>/dev/null
sync
setprop duo.patch applied
