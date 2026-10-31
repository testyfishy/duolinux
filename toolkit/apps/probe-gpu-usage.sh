#!/bin/sh
# What is the Adreno doing, and what is available to apps?
set -u
echo "=== GPU frequency/load if exposed"
for d in /sys/class/devfreq/*/; do
    n=$(cat "$d/name" 2>/dev/null)
    case "$n" in *gpu*|*3d*|*kgsl*|*6000000*)
        echo "  $n: cur=$(cat "$d/cur_freq" 2>/dev/null) load=$(cat "$d/gpu_load" 2>/dev/null || cat "$d/load" 2>/dev/null)"
    ;; esac
done
echo "  gpu_busy_percent: $(cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null || echo 'not exposed')"

echo
echo "=== who has the render node open right now"
for p in /proc/[0-9]*; do
    pid=${p#/proc/}
    if ls -l "$p/fd" 2>/dev/null | grep -q renderD128; then
        echo "  pid $pid: $(tr '\0' ' ' < "$p/cmdline" 2>/dev/null | cut -c1-60)"
    fi
done | head -12

echo
echo "=== graphics stack"
echo "  vulkan ICD in use: $(ls /usr/share/vulkan/icd.d/ | head -3 | tr '\n' ' ')"
echo "  mesa: $(dpkg -l | awk '/^ii/ && $2 ~ /^mesa-vulkan-drivers|^libgl1-mesa-dri/ {print $2"="$3}' | tr '\n' ' ')"
echo "  kwin renderer (from log):"
journalctl -b 0 --no-pager 2>/dev/null | grep -iE "kwin_wayland.*(opengl|gl |egl|renderer)" | tail -3 | sed 's/^/    /'

echo
echo "=== is VA-API possible? (hardware video decode)"
ls /dev/dri/renderD128 >/dev/null 2>&1 && echo "  render node: yes"
echo "  vainfo: $(command -v vainfo || echo not installed)"
echo "  v4l2 decoders: $(ls /dev/video* 2>/dev/null | tr '\n' ' ' || echo none)"
