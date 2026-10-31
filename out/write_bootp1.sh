#!/system/bin/sh
# Write the rebuilt boot partition (FAT, 512 MiB) to the microSD.
# Partition 1 only: the root filesystem, partition table and internal storage
# are untouched.
#
# Detaches so the "Run script as root" runner cannot kill it mid-write.
if [ "$1" != "detached" ]; then
  setsid sh "$0" detached >/dev/null 2>&1 &
  echo "started detached"
  exit 0
fi
sleep 1
set -e
gzip -dc /sdcard/Download/boot-p1.img.gz | dd of=/dev/block/mmcblk1p1 bs=4194304 conv=fsync
sync
setprop duo.bootp1 written
