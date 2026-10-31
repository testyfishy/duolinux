#!/bin/sh
set -u
echo "=== powerdevilrc (structure only, no secrets)"
su - duo -c 'cat ~/.config/powerdevilrc' 2>/dev/null | sed 's/^/  /' | head -60

echo
echo "=== does the key appear, and in which group?"
grep -n "inhibitLidAction\|^\[" /home/duo/.config/powerdevilrc 2>/dev/null

echo
echo "=== PowerDevil kcfg / schema defaults, if shipped"
find /usr/share -name "*powerdevil*.kcfg" 2>/dev/null | head -3
grep -rn "inhibitLidActionWhenExternalMonitorPresent" /usr/share/config.kcfg/ /usr/share/powerdevil/ 2>/dev/null | head -5
