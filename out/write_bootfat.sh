#!/system/bin/sh
# Replace the microSD boot partition with the rebuilt one.
# Only partition 1 (the 512 MiB FAT "ROCKNIX" partition) is written; the root
# filesystem, the partition table and internal storage are untouched.
#
# Detaches so the "Run script as root" runner cannot kill it mid-write.
if [ "$1" != "detached" ]; then
  setsid sh "$0" detached >/dev/null 2>&1 &
  echo "started detached"
  exit 0
fi
sleep 1
set -e
gzip -dc /sdcard/Download/boot-fat.img.gz | dd of=/dev/block/mmcblk1p1 bs=4194304 conv=fsync
sync
setprop duo.bootfat written
