#!/bin/sh
# Baseline before any gaming work: the checks that decide what is possible.
set -u
echo "=== ARMv8.1 LSE atomics (decides the native Steam client)"
n=$(grep -c -w atomics /proc/cpuinfo)
echo "  cores reporting 'atomics': $n of $(nproc)"
echo "  verdict: $([ "$n" -gt 0 ] && echo 'LSE present' || echo 'NO LSE - ARMv8.0 only')"
echo "  cpu part: $(grep -m1 'CPU part' /proc/cpuinfo | awk '{print $4}') (0xd03=A53, 0xd09=A73)"

echo
echo "=== Vulkan: is Turnip the real device, or llvmpipe?"
if command -v vulkaninfo >/dev/null 2>&1; then
    vulkaninfo --summary 2>/dev/null | grep -E "deviceName|driverName|driverInfo|apiVersion" | head -8
else
    echo "  vulkaninfo missing (vulkan-tools installed says otherwise?)"
    echo "  ICDs: $(ls /usr/share/vulkan/icd.d/ | tr '\n' ' ')"
fi

echo
echo "=== TUN (already proven by Tailscale running) "
ls -l /dev/net/tun 2>/dev/null || echo "  missing"

echo
echo "=== video decode devices (for Moonlight streaming)"
ls /dev/video* 2>/dev/null | tr '\n' ' '; echo
echo "  v4l2 decoders: $(v4l2-ctl --list-devices 2>/dev/null | head -4 || echo 'v4l-utils not installed')"

echo
echo "=== zram / swap"
zramctl 2>/dev/null | head -3 || cat /sys/block/zram0/mm_stat 2>/dev/null
free -m | sed -n '1,2p'

echo
echo "=== flatpak"
echo "  installed: $(command -v flatpak || echo no)"
echo "  flathub: $(flatpak remotes 2>/dev/null | grep -c flathub)"
