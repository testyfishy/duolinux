#!/bin/sh
# Pre-flight check of the eMMC install before switching the ABL boot source.
#
# The failure mode that matters after the switch is "boots but unreachable":
# no Wi-Fi profile, no root SSH key, wrong modules, no init. Check those on the
# eMMC rootfs while the device still boots from the SD card.
set -u

RK=/dev/mmcblk1p88
ST=/dev/mmcblk1p89
KVER=$(uname -r)

ok=0; bad=0
check() { if [ -e "$2" ] || [ -n "${3:-}" ]; then echo "ok    $1"; ok=$((ok+1)); else echo "MISS  $1 ($2)"; bad=$((bad+1)); fi; }

echo "=== filesystem and table checks (unmounted)"
umount /mnt/emmc 2>/dev/null || true
umount /mnt/rk 2>/dev/null || true
fsck.vfat -n "$RK" 2>&1 | tail -2
e2fsck -fn "$ST" 2>&1 | tail -2
sgdisk -v /dev/mmcblk1 2>&1 | tail -3

echo "=== ABL: how does it find the boot partition? (UTF-16 strings)"
for part in /dev/mmcblk1p67 /dev/mmcblk1p68; do
    echo "-- $part ($(sgdisk -i "${part##*p}" /dev/mmcblk1 | grep -o "Partition name: .*"))"
    strings -el "$part" 2>/dev/null | grep -iE "extlinux|rocknix|linux|boot" | sort -u | head -6
done

mkdir -p /mnt/emmc /mnt/rk
mountpoint -q /mnt/emmc || mount "$ST" /mnt/emmc || { echo "cannot mount eMMC root"; exit 1; }
mountpoint -q /mnt/rk || mount "$RK" /mnt/rk || { echo "cannot mount eMMC boot"; exit 1; }

echo "=== rootfs essentials"
check "init (systemd)"      /mnt/emmc/usr/lib/systemd/systemd
check "kernel modules $KVER" "/mnt/emmc/lib/modules/$KVER"
check "fstab"               /mnt/emmc/etc/fstab
check "machine-id"          /mnt/emmc/etc/machine-id
check "root authorized_keys" /mnt/emmc/root/.ssh/authorized_keys
check "duo user home"       /mnt/emmc/home/duo

echo "=== network reachability"
check "NetworkManager" /mnt/emmc/usr/sbin/NetworkManager
wifi=$(ls /mnt/emmc/etc/NetworkManager/system-connections/ 2>/dev/null | head -3)
[ -n "$wifi" ] && echo "ok    wifi profiles: $(echo "$wifi" | tr '\n' ' ')" || { echo "MISS  wifi profiles"; bad=$((bad+1)); }
[ -s /mnt/emmc/etc/ssh/ssh_host_ed25519_key ] && echo "ok    ssh host keys" || { echo "MISS  ssh host keys"; bad=$((bad+1)); }

echo "=== ssh keys match the current ones"
if [ -f /mnt/emmc/root/.ssh/authorized_keys ] && [ -f /root/.ssh/authorized_keys ]; then
    if cmp -s /mnt/emmc/root/.ssh/authorized_keys /root/.ssh/authorized_keys; then
        echo "ok    root authorized_keys identical"
    else
        echo "WARN  root authorized_keys differ"
    fi
fi

echo "=== services enabled"
for unit in ssh.service NetworkManager.service plasma-plasmashell.service inputplumber.service duo-lid.service duo-fan.service duo-backkey.service; do
    if ls /mnt/emmc/etc/systemd/system/*.wants/"$unit" >/dev/null 2>&1; then
        echo "ok    $unit"
    else
        echo "??    $unit not in a .wants dir (may be enabled elsewhere)"
    fi
done

echo "=== input stack"
ls -l /mnt/emmc/usr/local/bin/inputplumber 2>/dev/null | awk '{print "inputplumber bytes:", $5}'
[ -f /mnt/emmc/etc/systemd/system/inputplumber.service.d/override.conf ] && echo "ok    inputplumber override"
[ -f /mnt/emmc/etc/systemd/system/duo-mouse.service.d/partof.conf ] && echo "ok    duo-mouse PartOf"

echo "=== boot partition"
check "extlinux.conf" /mnt/rk/extlinux/extlinux.conf
check "KERNEL"        /mnt/rk/KERNEL
check "initrd.img"    /mnt/rk/initrd.img
check "dtb"           /mnt/rk/dtbs/qcom/sm6125-retroid-pocket-duo-lite.dtb
grep -q "root=LABEL=" /mnt/rk/extlinux/extlinux.conf && echo "ok    cmdline has root=LABEL="

echo "=== duo-init labels in the eMMC initrd"
rm -rf /tmp/preflight && mkdir -p /tmp/preflight && cd /tmp/preflight
zcat /mnt/rk/initrd.img 2>/dev/null | cpio -idm --quiet 2>/dev/null || true
grep -oE "LABEL=[A-Z_]+" duo-init 2>/dev/null | sort -u | sed 's/^/      /'

echo "=== labels vs GPT names"
blkid "$RK" "$ST" | sed 's/^/      /'
sgdisk -i 88 /dev/mmcblk1 | grep "Partition name"
sgdisk -i 89 /dev/mmcblk1 | grep "Partition name"
echo "      findfs STORAGE   -> $(findfs LABEL=STORAGE 2>/dev/null)"
echo "      findfs ROCKNIX   -> $(findfs LABEL=ROCKNIX 2>/dev/null)"

cd /
sync
umount /mnt/emmc
umount /mnt/rk

echo
echo "=== summary: $ok ok, $bad missing"
[ "$bad" -eq 0 ] && echo "READY (subject to the label caveat)" || echo "NOT READY: fix the MISS lines first"
