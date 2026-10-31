#!/bin/sh
set -u
echo "=== package / version"
dpkg -l tailscale 2>/dev/null | tail -2
tailscale version 2>/dev/null | head -2
echo "  binary: $(command -v tailscale) $(command -v tailscaled)"

echo
echo "=== is a systray binary shipped?"
for b in tailscale-systray tailscale systray; do
    p=$(command -v "$b" 2>/dev/null); [ -n "$p" ] && echo "  $b -> $p"
done
dpkg -L tailscale 2>/dev/null | grep -iE "systray|desktop|icon" | head
echo "  package files: $(dpkg -L tailscale 2>/dev/null | wc -l)"

echo
echo "=== local API socket and who may control it"
ls -l /var/run/tailscale/ 2>/dev/null
echo "  operator: $(tailscale debug prefs 2>/dev/null | grep -i operator)"

echo
echo "=== service user / how it runs"
systemctl show tailscaled -p ExecStart -p User --no-pager 2>/dev/null

echo
echo "=== Qt / KDE availability for a tray app"
echo "  Qt6 widgets: $(dpkg -l | grep -c 'libqt6widgets')"
echo "  Qt5 widgets: $(dpkg -l | grep -c 'libqt5widgets')"
echo "  plasma: $(plasmashell --version 2>/dev/null)"
echo "  statusnotifier host: $(dpkg -l | grep -c plasma-workspace)"

echo
echo "=== state"
tailscale status 2>&1 | head -2
