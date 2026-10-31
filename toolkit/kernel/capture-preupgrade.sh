#!/bin/sh
# Capture everything needed to reverse or replay a Plasma upgrade.
set -u
OUT=/var/tmp/duo-plasma-preupgrade
mkdir -p "$OUT"

echo "=== versions"
dpkg -l | awk '/^ii/ {print $2"="$3}' | sort > "$OUT/packages-all.txt"
apt-mark showmanual | sort > "$OUT/packages-manual.txt"
cp /var/lib/dpkg/status "$OUT/dpkg-status"
apt-cache policy > "$OUT/apt-policy.txt" 2>/dev/null
echo "  packages: $(wc -l < "$OUT/packages-all.txt"), manual: $(wc -l < "$OUT/packages-manual.txt")"

echo "=== kde/plasma/qt inventory"
dpkg -l | awk '/^ii/ && ($2 ~ /^(plasma|kwin|libkf6|libplasma|libqt6|qml6|kde)/) {print $2"="$3}' | sort > "$OUT/kde-stack.txt"
echo "  kde-stack packages: $(wc -l < "$OUT/kde-stack.txt")"

echo "=== configs that must survive"
tar -C / -czf "$OUT/configs.tgz" \
    etc/duo etc/systemd/system/duo-* etc/systemd/system/*.d \
    etc/systemd/logind.conf.d etc/udev/rules.d etc/polkit-1/rules.d \
    home/duo/.config/plasma-org.kde.plasma.desktop-appletsrc \
    home/duo/.config/kwinrc home/duo/.config/powerdevilrc \
    home/duo/.config/kglobalshortcutsrc home/duo/.config/kwinrulesrc \
    home/duo/.config/autostart home/duo/.local/share/plasma \
    usr/local/bin 2>/dev/null
echo "  configs.tgz: $(stat -c %s "$OUT/configs.tgz" 2>/dev/null) bytes"

echo "=== space"
df -h / | tail -1
echo "  sd storage: $(df -h /dev/mmcblk0p2 2>/dev/null | tail -1 || echo 'not mounted')"
lsblk -o NAME,SIZE,LABEL,MOUNTPOINT | grep -E "mmcblk0|mmcblk1p89"

echo "=== snapshot location: $OUT"
ls -la "$OUT"
