#!/bin/sh
# What Mesa/Turnip is installed, what is available, and what the Flatpak
# runtimes bring (apps use the runtime's Mesa, not the host's).
set -u
echo "=== host Mesa / Turnip"
dpkg -l | awk '/^ii/ && $2 ~ /mesa-vulkan-drivers|libgl1-mesa-dri|libvulkan1/ {print "  "$2"="$3}'
echo "  Turnip Vulkan reported:"
vulkaninfo --summary 2>/dev/null | grep -A2 "Turnip" | grep -E "apiVersion|driverInfo" | head -3 | sed 's/^/    /'

echo
echo "=== available versions (current sources)"
apt-cache policy mesa-vulkan-drivers libgl1-mesa-dri 2>/dev/null | sed 's/^/  /' | head -12

echo
echo "=== flatpak runtimes and their Mesa"
for r in $(flatpak list --runtime --columns=application,branch 2>/dev/null | awk '{print $1"/"$2}'); do
    echo "  $r"
done | head -10

echo
echo "=== does the GNOME runtime provide a newer Turnip?"
for base in /var/lib/flatpak/runtime/org.gnome.Platform/aarch64/*/active/files; do
    [ -d "$base" ] || continue
    echo "  $base"
    ls "$base/lib/aarch64-linux-gnu/" 2>/dev/null | grep -i "vulkan_freedreno\|libvulkan" | head -3 | sed 's/^/    /'
done
