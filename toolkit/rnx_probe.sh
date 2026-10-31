#!/bin/bash
S=/mnt/rnx/SYSTEM
echo "=== file(1):"; file "$S"
echo "=== blkid:"; blkid -p "$S" 2>&1 | head -3
echo "=== magic bytes:"; xxd -l 64 "$S" 2>/dev/null || od -A x -t x1z -N 64 "$S"
echo "=== md5 from image:"; cat "$(dirname "$S")/SYSTEM.md5"
echo "=== try mounts"
mkdir -p /mnt/rnxsys
for t in squashfs erofs ext4; do
  echo "-- $t"
  mount -t "$t" -o loop,ro "$S" /mnt/rnxsys 2>&1 | tail -1 || true
  if mountpoint -q /mnt/rnxsys; then
    echo "   MOUNTED as $t"
    ls /mnt/rnxsys | head -10
    umount /mnt/rnxsys
  fi
done
