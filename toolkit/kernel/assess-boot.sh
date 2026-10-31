#!/bin/bash
# Assessment run from the rescue SD. Read-only: mounts the eMMC boot partition
# and reports what is there, plus what the bootloader is asked to load.
set -uo pipefail

echo "=== running system"
echo "  kernel:  $(uname -r)"
echo "  cmdline: $(cat /proc/cmdline)"
echo "  root:    $(findmnt -no SOURCE /)"

echo
echo "=== eMMC layout"
lsblk -o NAME,SIZE,FSTYPE,LABEL /dev/mmcblk1 | tail -6

echo
echo "=== mounting the eMMC boot partition read-only"
mkdir -p /mnt/emmc
mount -o ro /dev/mmcblk1p88 /mnt/emmc 2>&1 | sed 's/^/  /'
if ! mountpoint -q /mnt/emmc; then
    echo "  could not mount"; exit 1
fi

echo
echo "=== boot files"
ls -l --time-style=+%m-%d\ %H:%M /mnt/emmc/KERNEL* 2>/dev/null | sed 's/^/  /'
ls -l --time-style=+%m-%d\ %H:%M /mnt/emmc/dtbs/qcom/ 2>/dev/null | sed 's/^/  /'

echo
echo "=== checksums"
sha256sum /mnt/emmc/KERNEL /mnt/emmc/KERNEL.dmic 2>/dev/null | sed 's/^/  /'
sha256sum /mnt/emmc/dtbs/qcom/sm6125-retroid-pocket-duo-lite.dtb \
          /mnt/emmc/dtbs/qcom/sm6125-retroid-pocket-duo-lite.dtb.dmic 2>/dev/null | sed 's/^/  /'

echo
echo "=== what the bootloader is told to load"
for f in /mnt/emmc/extlinux/extlinux.conf /mnt/emmc/loader/entries/*.conf; do
    [ -f "$f" ] || continue
    echo "  --- $f"
    sed 's/^/    /' "$f"
done

echo
echo "=== the installed DTB's bus layout (our build was 64-bit)"
python3 - <<'PY'
import subprocess, re
out = subprocess.run(["strings", "/mnt/emmc/dtbs/qcom/sm6125-retroid-pocket-duo-lite.dtb"],
                     capture_output=True, text=True).stdout
print("  MIC BIAS1 strings:", out.count("MIC BIAS1"))
print("  TX DMIC strings:  ", out.count("TX DMIC"))
PY

echo
echo "=== eMMC root filesystem"
mount -o ro /dev/mmcblk1p89 /mnt/emmcroot 2>/dev/null && {
    echo "  mounted; systemd state: $(cat /mnt/emmcroot/etc/hostname 2>/dev/null)"
    echo "  modules for the installed kernel: $(ls -d /mnt/emmcroot/lib/modules/* 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"
    umount /mnt/emmcroot
} || echo "  could not mount /dev/mmcblk1p89"

echo
echo "=== SD card's own boot files (known good)"
ls -l --time-style=+%m-%d\ %H:%M /mnt/emmc 2>/dev/null >/dev/null
ls -l --time-style=+%m-%d\ %H:%M /boot 2>/dev/null | head -8 | sed 's/^/  /'

umount /mnt/emmc
echo
echo "DONE"
