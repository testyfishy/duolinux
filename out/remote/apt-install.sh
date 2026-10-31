#!/bin/bash
set -u
export DEBIAN_FRONTEND=noninteractive
echo "=== force IPv4 test"
timeout 25 curl -4 -sI https://deb.debian.org/debian/ 2>&1 | head -3
echo "=== apt update"
apt-get -o Acquire::ForceIPv4=true update 2>&1 | tail -5
echo "=== install apps"
apt-get -o Acquire::ForceIPv4=true install -y --no-install-recommends \
  firefox-esr pcmanfm syncthing wvkbd rsync 2>&1 | tail -12
echo "=== versions"
for b in firefox-esr pcmanfm syncthing wvkbd rsync; do
  printf '%-12s %s\n' "$b" "$(command -v "$b" 2>/dev/null || echo MISSING)"
done
