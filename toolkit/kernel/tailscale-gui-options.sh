#!/bin/sh
set -u
echo "=== what Debian offers"
apt-cache search tailscale 2>/dev/null | head -10
echo "--- policy:"
apt-cache policy tailscale 2>/dev/null | head -8

echo
echo "=== is the upstream repo configured?"
grep -rl "pkgs.tailscale.com" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null || echo "  no upstream repo"

echo
echo "=== does any package ship a systray binary?"
apt-file search tailscale-systray 2>/dev/null | head -5 || echo "  (apt-file not installed)"

echo
echo "=== what the upstream .deb would add (from the installed one's file list)"
dpkg -L tailscale | sed 's/^/  /'

echo
echo "=== python/Qt options for a tray client"
echo "  python3: $(python3 --version 2>&1)"
for m in PyQt6 PySide6 dbus gi; do
    python3 -c "import $m" 2>/dev/null && echo "  $m: yes" || echo "  $m: no"
done
apt-cache policy python3-pyqt6 2>/dev/null | head -3
