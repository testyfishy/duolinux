#!/bin/sh
set -u
echo "=== GTK / appindicator plumbing"
for p in gir1.2-gtk-3.0 gir1.2-ayatanaappindicator3-0.1 gir1.2-appindicator3-0.1 python3-gi; do
    printf '  %-38s %s\n' "$p" "$(dpkg -l "$p" 2>/dev/null | awk '/^ii/{print $3}' || echo -)"
done
echo "  libayatana-appindicator: $(ldconfig -p 2>/dev/null | grep -c ayatana)"
echo "  libappindicator:         $(ldconfig -p 2>/dev/null | grep -c 'libappindicator3')"

echo
echo "=== gi typelibs present"
ls /usr/lib/*/girepository-1.0/ 2>/dev/null | grep -iE "gtk|ayatana|appindicator|notify" | head

echo
echo "=== what tailscale exposes locally (for a GUI to drive)"
tailscale status --json 2>/dev/null | head -c 300; echo
echo "  ---"
tailscale debug prefs 2>/dev/null | head -c 200; echo

echo
echo "=== does the desktop already have third-party tailscale UI?"
ls ~duo/.local/share/plasma/plasmoids 2>/dev/null | grep -i tail || echo "  no plasmoid"
