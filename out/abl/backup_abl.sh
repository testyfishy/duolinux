#!/system/bin/sh
# Back up the stock ABL to this folder. Run as root.
set -e
BASE="$(cd "$(dirname "$0")" && pwd)"
dd if=/dev/block/by-name/abl_a of="$BASE/abl_a.img" bs=1M
if [ -e /dev/block/by-name/abl_b ]; then
  dd if=/dev/block/by-name/abl_b of="$BASE/abl_b.img" bs=1M
fi
sync
echo "backups written to $BASE"
