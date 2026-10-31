#!/bin/bash
# Install the kernel and modules *only*, leaving the device tree alone.
#
# The DTB on this device is the vendor blob with the mic routing patched in by
# fdtput; replacing it with a rebuild from the ported tree panics the boot
# (32-bit vs 64-bit #address-cells). install-nf.sh copies both, so it must not
# be used for kernel-only iterations.
set -euo pipefail
W=$HOME/rocknix-nf
KEY=$HOME/.ssh/duo_key
H=root@192.168.86.33
SSH="ssh -i $KEY -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
SCP="scp -q -i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

ls -l "$W/KERNEL-7.2.11-nf" "$W/modules-7.2.11-nf.tgz" >/dev/null || {
    echo "no build output" >&2; exit 1; }
echo "  kernel: $(zcat "$W/KERNEL-7.2.11-nf" | strings | grep -m1 'Linux version' || true)"

$SCP "$W/KERNEL-7.2.11-nf" "$W/modules-7.2.11-nf.tgz" "$H:/tmp/"

$SSH "$H" '
set -e
mount /dev/mmcblk1p88 /mnt/boot 2>/dev/null || true
# keep the current kernel as the rollback, and be explicit about the DTB
[ -f /mnt/boot/KERNEL.prev ] || cp -p /mnt/boot/KERNEL /mnt/boot/KERNEL.prev
DTB=/mnt/boot/dtbs/qcom/sm6125-retroid-pocket-duo-lite.dtb
BEFORE=$(sha256sum "$DTB" | cut -d" " -f1)
tar -C / -xzf /tmp/modules-7.2.11-nf.tgz
depmod -a 7.2.11-nf
cp /tmp/KERNEL-7.2.11-nf /mnt/boot/KERNEL
sync
AFTER=$(sha256sum "$DTB" | cut -d" " -f1)
echo "  kernel: $(stat -c %s /mnt/boot/KERNEL) bytes"
echo "  dtb unchanged: $([ "$BEFORE" = "$AFTER" ] && echo yes || echo NO)"
umount /mnt/boot 2>/dev/null || umount -l /mnt/boot
echo INSTALLED
'

echo
echo "=== reboot"
$SSH "$H" 'sync; systemctl reboot' 2>/dev/null || true
sleep 30
for i in $(seq 1 30); do
    $SSH "$H" 'true' 2>/dev/null && { echo "  back"; break; }
    sleep 5
done
sleep 6
$SSH "$H" 'echo "  running: $(uname -r) up $(uptime -p)"'
