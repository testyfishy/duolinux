#!/bin/bash
# Finish copying the rescue archive, surviving link drops.
#
# The handheld suspends on idle, which kills the transfer; a systemd inhibitor
# on the device holds sleep off while this runs, and rsync restarts from the
# partial file each attempt.
set -uo pipefail
KEY=$HOME/.ssh/duo_key
SSH="ssh -i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15"
SRC=root@192.168.86.33:/mnt/usb/duo-backup-20261031-1935/
DST="/mnt/c/Users/HTPC-Aran/Documents/duo-backups/20261031-1935/"
FILE=sd-rootfs.tar.zst

echo "=== holding sleep off on the device"
$SSH root@192.168.86.33 'pkill -f "systemd-inhibit.*usb backup" 2>/dev/null; setsid systemd-inhibit --what=sleep:idle --mode=block --why="usb backup" sleep 3600 >/dev/null 2>&1 & echo started'

remote=$( $SSH root@192.168.86.33 "stat -c %s /mnt/usb/duo-backup-20261031-1935/$FILE" )
echo "  remote size: $remote"

for i in $(seq 1 8); do
    local_size=$(stat -c %s "$DST$FILE" 2>/dev/null || echo 0)
    echo "=== attempt $i (local $local_size / $remote)"
    if [ "$local_size" = "$remote" ]; then break; fi
    rsync -a --partial --inplace --append-verify -e "$SSH" "$SRC" "$DST" 2>&1 | tail -2
    sleep 5
done

echo "=== verify"
l=$(stat -c %s "$DST$FILE" 2>/dev/null || echo 0)
echo "  local:  $l"
echo "  remote: $remote"
if [ "$l" = "$remote" ]; then
    echo "  MATCH - checking digests"
    a=$($SSH root@192.168.86.33 "sha256sum /mnt/usb/duo-backup-20261031-1935/$FILE" | cut -d" " -f1)
    b=$(sha256sum "$DST$FILE" | cut -d" " -f1)
    echo "  remote sha256: $a"
    echo "  local  sha256: $b"
    [ "$a" = "$b" ] && echo "  DIGEST OK" || echo "  DIGEST MISMATCH"
else
    echo "  STILL INCOMPLETE"
fi

echo "=== releasing sleep inhibitor"
$SSH root@192.168.86.33 'pkill -f "systemd-inhibit.*usb backup" 2>/dev/null; echo released'
