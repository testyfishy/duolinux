#!/bin/bash
# Install the venus DTB on the boot partition, keeping both rollbacks:
#   .dtb.audio  - the current good tree (vendor layout + audio routing)
#   .dtb.dmic   - the pristine vendor blob
set -euo pipefail
KEY=$HOME/.ssh/duo_key
H=root@192.168.86.33
SSH="ssh -i $KEY -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
SCP="scp -q -i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

$SCP "$HOME/rocknix-nf/dtb-venus.dtb" "$H:/tmp/dtb-venus.dtb"

$SSH "$H" '
set -e
mount /dev/mmcblk1p88 /mnt/boot
D=/mnt/boot/dtbs/qcom/sm6125-retroid-pocket-duo-lite.dtb
[ -f "$D.dmic" ] || cp -p "$D" "$D.dmic"
cp -p "$D" "$D.audio"
cp /tmp/dtb-venus.dtb "$D"
sync
echo "  installed: $(stat -c %s "$D") bytes"
echo "  rollbacks: audio=$(stat -c %s "$D.audio") dmic=$(stat -c %s "$D.dmic")"
umount /mnt/boot
'

echo "=== rebooting"
$SSH "$H" 'sync; systemctl reboot' 2>/dev/null || true
sleep 40
for i in $(seq 1 24); do
    $SSH "$H" 'true' 2>/dev/null && break
    sleep 5
done
sleep 8
$SSH "$H" '
echo "  back: $(uname -r)"
echo "  venus in dmesg:"; dmesg | grep -i venus | head -10 | sed "s/^/    /"
echo "  video devices:"; ls /dev/video* 2>/dev/null | sed "s/^/    /" || echo "    none"
'
