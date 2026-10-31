#!/bin/sh
# Ask Debian what Plasma versions exist in the newer suites, without installing.
# The temporary source list is removed at the end.
set -u
T=/etc/apt/sources.list.d/zz-probe.list
rm -f "$T"
for s in trixie-backports forky sid; do
    echo "deb http://deb.debian.org/debian $s main" >> "$T"
done
apt-get update -o Dir::Etc::sourcelist="$T" -o Dir::Etc::sourceparts=- -qq 2>&1 | tail -3

echo "=== plasma-desktop"
apt-cache policy plasma-desktop 2>/dev/null | sed -n '1,12p'
echo "=== plasma-workspace"
apt-cache policy plasma-workspace 2>/dev/null | sed -n '1,10p'
echo "=== kwin-wayland"
apt-cache policy kwin-wayland 2>/dev/null | sed -n '1,10p'
echo "=== kf6 / qt6 base versions available"
apt-cache policy libkf6coreaddons6 libqt6core6t64 2>/dev/null | sed -n '1,14p'

rm -f "$T"
apt-get update -qq 2>&1 | tail -2
echo "=== probe source removed: $(ls "$T" 2>/dev/null || echo yes)"
