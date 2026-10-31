#!/system/bin/sh
# DuoLinux ABL installer — run as root from this folder on the SD card.
# Backs up the stock ABL next to this script before writing.
set -e
BASE="$(cd "$(dirname "$0")" && pwd)"
ELF="$BASE/abl_signed-SM6115.elf"
[ -f "$ELF" ] || { echo "missing $ELF"; exit 1; }

echo "backing up stock ABL to $BASE"
dd if=/dev/block/by-name/abl_a of="$BASE/abl_a.img" bs=1M
if [ -e /dev/block/by-name/abl_b ]; then
  dd if=/dev/block/by-name/abl_b of="$BASE/abl_b.img" bs=1M
fi

echo "flashing ROCKNIX SM6115 ABL..."
dd if="$ELF" of=/dev/block/by-name/abl_a bs=1M
if [ -e /dev/block/by-name/abl_b ]; then
  dd if="$ELF" of=/dev/block/by-name/abl_b bs=1M
fi
sync
echo
echo "Done. Copy abl_a.img/abl_b.img off the card before relying on this."
echo "Power off, then hold Volume Down at power-on."
echo "Set Boot mode = Linux and Boot source = SD Card."
