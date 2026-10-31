#!/bin/sh
set -u
echo "=== packages relevant to x86 games on arm64 (trixie + what's newer)"
for p in box64 box86 fex-emu fex-emu-binfmt wine wine64 wine32 lutris steam gamescope mangohud \
         vkbasalt dxvk vkd3d-proton proton-cachyos pressure-vessel gamemode vulkan-tools zink; do
    pol=$(apt-cache policy "$p" 2>/dev/null | tr '\n' ' ')
    inst=$(echo "$pol" | sed -n 's/.*Installed: \([^ ]*\).*/\1/p')
    cand=$(echo "$pol" | sed -n 's/.*Candidate: \([^ ]*\).*/\1/p')
    [ -n "$cand" ] && echo "  $p: installed=${inst:-no} candidate=${cand:-none}"
done

echo
echo "=== search for translation layers in the archive"
apt-cache search -n 'box86|box64|fex-emu|wine|proton|gamescope' 2>/dev/null | head -15

echo
echo "=== GPU / Vulkan stack"
echo "  gpu: $(cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null || echo n/a)"
ls /usr/share/vulkan/icd.d/ 2>/dev/null | sed 's/^/  icd: /'
echo "  mesa: $(dpkg -l | awk '/^ii/ && $2 ~ /mesa-vulkan|libvulkan/ {print $2"="$3}' | tr '\n' ' ')"
echo "  turnip: $(ls /usr/lib/aarch64-linux-gnu/libvulkan_freedreno.so 2>/dev/null || echo absent)"

echo
echo "=== storage"
df -h / | tail -1
echo "  sd: $(lsblk -o SIZE,LABEL,MOUNTPOINT -n /dev/mmcblk0p2 2>/dev/null | tr -s ' ')"

echo
echo "=== syncthing availability"
apt-cache policy syncthing 2>/dev/null | sed -n '1,4p'

echo
echo "=== cpu features relevant to x86 translation"
grep -m1 Features /proc/cpuinfo | tr ' ' '\n' | grep -E "^(asimd|sha1|sha2|crc32|aes|pmull|fp|asimdrdm)$" | tr '\n' ' '; echo
echo "  cores: $(nproc) ($(grep -m1 'CPU part' /proc/cpuinfo | awk '{print $4}'))"
