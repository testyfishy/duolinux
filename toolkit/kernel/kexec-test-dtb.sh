#!/bin/bash
# Boot the current kernel with the test DTB via kexec.
#
# The boot partition is not touched: if the tree is bad the kernel panics, the
# device reboots (panic=30) and comes back on the normal DTB.
set -uo pipefail
KEY=$HOME/.ssh/duo_key
H=root@192.168.1.33
SSH="ssh -i $KEY -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
SCP="scp -q -i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

echo "=== bootloader identity of the test DTB"
fdtget -t x "$HOME/rocknix-nf/dtb-va-test.dtb" / qcom,msm-id 2>/dev/null | sed 's/^/  test msm-id: /'
fdtget -t x "$HOME/rocknix-nf/dtb-va-test.dtb" / qcom,board-id 2>/dev/null | sed 's/^/  test board-id: /'
fdtget -t x "/mnt/c/Users/user/Documents/Default Project/duolinux/out/kernel/sm6125-retroid-pocket-duo-lite.dtb" / qcom,msm-id 2>/dev/null | sed 's/^/  vendor msm-id: /'

echo
echo "=== shipping"
$SCP "$HOME/rocknix-nf/dtb-va-test.dtb" "$H:/tmp/dtb-va-test.dtb"

echo "=== preparing the kexec image"
$SSH "$H" '
set -e
mount /dev/mmcblk1p88 /mnt/boot 2>/dev/null || true
zcat /mnt/boot/KERNEL > /tmp/Image
ls -l /tmp/Image /mnt/boot/initrd.img /tmp/dtb-va-test.dtb | sed "s/^/  /"
echo "  cmdline: $(cat /proc/cmdline)"
'

echo
echo "=== kexec -l (validates the image + dtb)"
$SSH "$H" '
set -e
kexec -l /tmp/Image --dtb=/tmp/dtb-va-test.dtb --initrd=/mnt/boot/initrd.img \
      --command-line="$(cat /proc/cmdline)" 2>&1 | head -5
echo "  loaded: $(cat /sys/kernel/kexec_loaded 2>/dev/null)"
'
