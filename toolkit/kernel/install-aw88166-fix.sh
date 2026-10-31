#!/bin/bash
# Install the aw88166-fixed kernel and set a sane volume before any sound plays.
set -euo pipefail
W=$HOME/rocknix-nf
KEY=$HOME/.ssh/duo_key
H=root@192.168.1.33

echo "=== artefacts"
ls -l "$W/KERNEL-7.2.11-nf" "$W/modules-7.2.11-nf.tgz"
zcat "$W/KERNEL-7.2.11-nf" | strings | grep -m1 "Linux version"

echo
echo "=== shipping to the device"
scp -q -i "$KEY" -o StrictHostKeyChecking=no \
    "$W/KERNEL-7.2.11-nf" "$W/modules-7.2.11-nf.tgz" "$H:/tmp/"

echo "=== installing (modules first, then the image, keeping the old one)"
ssh -i "$KEY" -o StrictHostKeyChecking=no "$H" '
set -e
tar -C / -xzf /tmp/modules-7.2.11-nf.tgz
depmod -a 7.2.11-nf
mount /dev/mmcblk1p88 /mnt/boot
cd /mnt/boot
[ -f KERNEL.721nf ] || cp -p KERNEL KERNEL.721nf   # pre-fix 7.2.11-nf
cp /tmp/KERNEL-7.2.11-nf KERNEL
sync
echo "  KERNEL        $(stat -c %s KERNEL)"
echo "  KERNEL.721nf  $(stat -c %s KERNEL.721nf)"
cd /
umount /mnt/boot 2>/dev/null || umount -l /mnt/boot
echo INSTALLED
'

echo
echo "=== reboot"
ssh -i "$KEY" -o StrictHostKeyChecking=no "$H" 'systemctl reboot' || true
sleep 25
for i in $(seq 1 24); do
    if ssh -i "$KEY" -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no "$H" 'true' 2>/dev/null; then
        echo "  back after ~$((25 + i * 5))s"
        break
    fi
    sleep 5
done

echo
echo "=== set a moderate volume BEFORE testing (900 of 1023 ~= -15 dB)"
ssh -i "$KEY" -o StrictHostKeyChecking=no "$H" '
echo "  kernel: $(uname -r)"
amixer -c 0 sset numid=2 900 >/dev/null 2>&1 || true
amixer -c 0 sset numid=8 900 >/dev/null 2>&1 || true
for id in 2 8; do
  echo "  numid=$id -> $(amixer -c 0 cget numid=$id 2>/dev/null | grep -oE "values=[0-9]+" | head -1)"
done
'
