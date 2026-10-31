#!/bin/bash
# Step 1: correct the clock, then install the apps that were missing.
set -u
export DEBIAN_FRONTEND=noninteractive

echo "=== installed kernel packages (must not change)"
dpkg -l | awk '/^ii/ && $2 ~ /^linux-image|^flash-kernel/{print $2, $3}'
echo "(end)"

echo "=== set clock"
date -u -s "@__NOW__" 2>&1
date -u

echo "=== enable time sync"
apt-get -o Acquire::ForceIPv4=true install -y --no-install-recommends systemd-timesyncd 2>&1 | tail -4
systemctl enable --now systemd-timesyncd 2>&1 | tail -2
sleep 3
timedatectl 2>&1 | head -8

echo "=== apt update"
apt-get -o Acquire::ForceIPv4=true update 2>&1 | tail -4

echo "=== install apps"
apt-get -o Acquire::ForceIPv4=true install -y --no-install-recommends \
  firefox-esr pcmanfm syncthing wvkbd rsync i3status 2>&1 | tail -10

echo "=== verify no kernel appeared"
dpkg -l | awk '/^ii/ && $2 ~ /^linux-image|^flash-kernel/{print $2, $3}'
echo "(end)"

echo "=== versions"
for b in firefox-esr pcmanfm syncthing wvkbd rsync i3status; do
  printf '%-14s %s\n' "$b" "$(command -v "$b" 2>/dev/null || echo MISSING)"
done
