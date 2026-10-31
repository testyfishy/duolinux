#!/bin/bash
set -u
export DEBIAN_FRONTEND=noninteractive
echo "=== build deps"
apt-get -o Acquire::ForceIPv4=true install -y --no-install-recommends \
    build-essential git pkg-config libcairo2-dev libpango1.0-dev \
    libwayland-dev wayland-protocols libxkbcommon-dev 2>&1 | tail -3

echo "=== installed wvkbd version"
dpkg -l wvkbd 2>/dev/null | tail -1

echo "=== fetch source"
cd /root || exit 1
rm -rf wvkbd
git clone --depth 1 --branch v0.15 https://github.com/proycon/wvkbd.git 2>&1 | tail -3 || \
git clone --depth 1 https://github.com/proycon/wvkbd.git 2>&1 | tail -3

ls /root/wvkbd 2>/dev/null | head -20
echo "=== layer surface creation in main.c"
grep -n "layer_surface\|wl_output\|output" /root/wvkbd/main.c 2>/dev/null | head -30
