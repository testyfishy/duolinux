#!/bin/sh
# Inventory of everything we wrote, so we can ask what upstream replaces.
set -u
echo "=== our binaries in /usr/local/bin"
ls -1 /usr/local/bin/ 2>/dev/null | sed 's/^/  /'

echo
echo "=== our system units"
systemctl list-unit-files --no-legend 'duo-*' 2>/dev/null | awk '{print "  "$1" "$2}'

echo
echo "=== our user units"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user list-unit-files --no-legend "duo-*"' 2>/dev/null | awk '{print "  "$1" "$2}'

echo
echo "=== autostart entries (ours)"
ls -1 /home/duo/.config/autostart/ 2>/dev/null | sed 's/^/  /'

echo
echo "=== which of our daemons are running now"
for p in $(pgrep -f 'duo-|wvkbd' 2>/dev/null); do
    tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | cut -c1-60
    echo
done | sort -u | sed 's/^/  /'

echo
echo "=== upstream packages that already provide these functions"
for p in lm-sensors fancontrol coolercontrol wvkbd inputplumber swayidle; do
    c=$(apt-cache policy "$p" 2>/dev/null | sed -n 's/.*Candidate: //p')
    printf '  %-14s %s\n' "$p" "${c:-not packaged}"
done
