#!/bin/bash
# Is there an upstream PowerDevil setting that stops the lid being ignored when
# the DP-1 panel looks like an external monitor?
set -u
echo "=== powerdevil packages"
dpkg -l | awk '/powerdevil/{print "  "$2"="$3}'

echo
echo "=== strings mentioning external monitor / lid inhibit"
for f in $(ls /usr/lib/aarch64-linux-gnu/libpowerdevilcore.so* 2>/dev/null; ls /usr/lib/aarch64-linux-gnu/qt6/plugins/powerdevil*/*.so 2>/dev/null); do
    [ -f "$f" ] || continue
    hits=$(strings "$f" 2>/dev/null | grep -iE "externalmonitor|external monitor|InhibitLid" | head -4)
    [ -n "$hits" ] && echo "  ${f##*/}:" && echo "$hits" | sed 's/^/    /'
done

echo
echo "=== current powerdevilrc lid keys"
su - duo -c 'cat ~/.config/powerdevilrc 2>/dev/null' | grep -iE "lid|inhibit" | head -10

echo
echo "=== kcfg schema mentions"
grep -rl "InhibitLidAction\|LidAction" /usr/share/config.kcfg/ 2>/dev/null | head -5
grep -rh "InhibitLid" /usr/share/config.kcfg/*.kcfg 2>/dev/null | head -5
