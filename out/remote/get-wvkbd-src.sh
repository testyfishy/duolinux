#!/bin/bash
set -u
cd /root || exit 1
rm -rf wvkbd wvkbd-0.15 wvkbd.tar.gz

echo "=== fetch Debian source tarball"
timeout 60 curl -4 -sL -o wvkbd.tar.gz \
  https://deb.debian.org/debian/pool/main/w/wvkbd/wvkbd_0.15.orig.tar.gz
ls -l wvkbd.tar.gz 2>/dev/null || echo "download failed"

tar xzf wvkbd.tar.gz 2>/dev/null
DIR=$(ls -d /root/wvkbd-* 2>/dev/null | head -1)
echo "source dir: ${DIR:-none}"
[ -n "$DIR" ] || exit 1

echo "=== files"
ls "$DIR" | head -20

echo "=== how the layer surface is created"
grep -n "layer_surface\|zwlr_layer_surface\|wl_output" "$DIR"/*.c | head -30
