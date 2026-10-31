#!/system/bin/sh
# Restore the stock ABL backups from this folder. Run as root.
set -e
BASE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$BASE/abl_a.img" ] || { echo "missing $BASE/abl_a.img"; exit 1; }
dd if="$BASE/abl_a.img" of=/dev/block/by-name/abl_a bs=1M
if [ -e /dev/block/by-name/abl_b ] && [ -f "$BASE/abl_b.img" ]; then
  dd if="$BASE/abl_b.img" of=/dev/block/by-name/abl_b bs=1M
fi
sync
echo "stock ABL restored"
