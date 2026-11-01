#!/bin/bash
# Wait for the handheld to wake, then unmount and power the USB drive off so it
# can be physically removed.
set -uo pipefail
KEY=$HOME/.ssh/duo_key
SSH="ssh -i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o BatchMode=yes"
H=root@192.168.1.33

echo "waiting for the device (up to 3 minutes)"
for i in $(seq 1 36); do
    if $SSH $H true 2>/dev/null; then
        echo "  awake after ~$((i*5))s"
        break
    fi
    sleep 5
done

if ! $SSH $H true 2>/dev/null; then
    echo "still asleep - nothing ejected"
    exit 1
fi

$SSH $H '
set -u
echo "=== before"
findmnt -no TARGET -S /dev/sda1 2>/dev/null | sed "s/^/  mounted at /" || echo "  not mounted"
BLOCK=$(readlink -f /dev/disk/by-label/ESD-USB 2>/dev/null | sed "s/p[0-9]*$//")
[ -n "${BLOCK:-}" ] || BLOCK=/dev/sda

echo "=== syncing"
sync; sleep 1

echo "=== unmounting"
for m in $(findmnt -rno TARGET -S /dev/sda1 2>/dev/null); do
    umount "$m" && echo "  unmounted $m"
done
umount /mnt/usb 2>/dev/null || true

echo "=== powering off $BLOCK"
if command -v udisksctl >/dev/null; then
    udisksctl power-off -b "$BLOCK" 2>&1 | sed "s/^/  /"
else
    echo 1 > "/sys/block/$(basename $BLOCK)/device/delete" && echo "  detached via sysfs"
fi
sleep 2
echo "=== after"
lsblk -o NAME,SIZE,LABEL | grep -iE "sda|ESD" || echo "  sda is gone - safe to remove"
'
