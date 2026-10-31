#!/bin/bash
# Install the aw88166 volume fix, then test the floor step by step.
set -euo pipefail
W=$HOME/rocknix-nf
KEY=$HOME/.ssh/duo_key
H=root@192.168.86.33
SSH="ssh -i $KEY -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=10"

echo "=== artefact"
ls -l "$W/KERNEL-7.2.11-nf" "$W/modules-7.2.11-nf.tgz"
zcat "$W/KERNEL-7.2.11-nf" | strings | grep -m1 "Linux version"

echo
echo "=== ship + install"
scp -q -i "$KEY" -o StrictHostKeyChecking=no \
    "$W/KERNEL-7.2.11-nf" "$W/modules-7.2.11-nf.tgz" "$H:/tmp/"
$SSH "$H" '
set -e
tar -C / -xzf /tmp/modules-7.2.11-nf.tgz
depmod -a 7.2.11-nf
mount /dev/mmcblk1p88 /mnt/boot
cd /mnt/boot
[ -f KERNEL.721nf ] || cp -p KERNEL KERNEL.721nf
cp /tmp/KERNEL-7.2.11-nf KERNEL
sync
echo "  KERNEL $(stat -c %s KERNEL)  backup $(stat -c %s KERNEL.721nf)"
cd /
umount /mnt/boot 2>/dev/null || umount -l /mnt/boot
echo INSTALLED
'

echo
echo "=== reboot"
$SSH "$H" 'systemctl reboot' 2>/dev/null || true
sleep 25
for i in $(seq 1 24); do
    $SSH "$H" 'true' 2>/dev/null && { echo "  back"; break; }
    sleep 5
done
sleep 8

echo
echo "=== volume control semantics after the fix"
$SSH "$H" '
echo "  kernel: $(uname -r)"
echo "  control before: $(amixer -c 0 cget numid=2 2>/dev/null | grep -oE "values=[0-9]+" | head -1)"
echo "  amp attenuation: $(grep -E "^05:" /sys/kernel/debug/regmap/0-0034/registers 2>/dev/null)"
'
