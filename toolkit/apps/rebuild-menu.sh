#!/bin/sh
set -u
echo "=== moonlight desktop entry"
cat /var/lib/flatpak/exports/share/applications/com.moonlight_stream.Moonlight.desktop 2>/dev/null | head -12

echo
echo "=== does the session's menu see flatpak exports?"
echo "  XDG_DATA_DIRS would include: /var/lib/flatpak/exports/share"
ls -l /var/lib/flatpak/exports/share/applications/*.desktop | wc -l

echo
echo "=== rebuild with the plasma menu prefix, as the desktop user"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 XDG_MENU_PREFIX=plasma- kbuildsycoca6 --noincremental' 2>&1 | tail -4

echo
echo "=== is the Tailscale entry valid?"
grep -E "^Exec=|^Type=|^Name=" /home/duo/.local/share/applications/duo-tailscale.desktop
update-desktop-database /home/duo/.local/share/applications 2>&1 | tail -2

echo
echo "=== quick validity check on both"
for f in /home/duo/.local/share/applications/duo-tailscale.desktop \
         /var/lib/flatpak/exports/share/applications/com.moonlight_stream.Moonlight.desktop; do
    echo "  $f: $(desktop-file-validate "$f" 2>&1 | head -2 || echo ok)"
done
