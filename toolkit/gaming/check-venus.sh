#!/bin/sh
set -u
echo "=== is Venus in the running kernel?"
echo "  CONFIG_VIDEO_QCOM_VENUS: $(grep -E '^CONFIG_VIDEO_QCOM_VENUS' /proc/config.gz 2>/dev/null >/dev/null; zcat /proc/config.gz 2>/dev/null | grep -E '^CONFIG_VIDEO_QCOM_VENUS' || echo unset)"
for s in VIDEO_QCOM_VENUS VIDEO_DEV MEDIA_SUPPORT V4L_MEM2MEM_DRIVERS VIDEO_V4L2_M2M; do
    echo "  $s: $(zcat /proc/config.gz 2>/dev/null | grep -E "^CONFIG_$s=" || echo unset)"
done

echo
echo "=== is the venus node in the device tree?"
grep -c "venus" /sys/firmware/devicetree/base/soc@0/*/compatible 2>/dev/null || true
echo "  dmesg venus: $(dmesg | grep -ci venus) lines"
dmesg | grep -i venus | head -3

echo
echo "=== firmware present?"
ls /lib/firmware/qcom/venus* 2>/dev/null || echo "  no venus firmware directory"
find /lib/firmware -iname "*venus*" 2>/dev/null | head -8

echo
echo "=== does the built kernel tree have the driver source?"
K=$HOME/rocknix-nf/port/repo
ls "$K/drivers/media/platform/qcom/venus/" 2>/dev/null | head -5
echo "  Kconfig entry: $(grep -A4 'config VIDEO_QCOM_VENUS' "$K/drivers/media/platform/qcom/venus/Kconfig" 2>/dev/null | head -5)"

echo
echo "=== v4l2 tooling"
echo "  v4l2-ctl: $(command -v v4l2-ctl || echo 'not installed (v4l-utils)')"
