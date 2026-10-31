#!/bin/bash
set -u
cd /root || exit 1
rm -rf wvkbd wvkbd-0.15 wvkbd_0.15.orig.tar.xz

timeout 60 curl -4 -sL -o wvkbd_0.15.orig.tar.xz \
  https://deb.debian.org/debian/pool/main/w/wvkbd/wvkbd_0.15.orig.tar.xz
ls -l wvkbd_0.15.orig.tar.xz

tar xJf wvkbd_0.15.orig.tar.xz
DIR=$(ls -d /root/wvkbd-* 2>/dev/null | head -1)
echo "dir: $DIR"
[ -n "$DIR" ] || exit 1

echo "=== source files"
ls "$DIR" | head -20

echo "=== layer surface creation"
grep -n "zwlr_layer_surface_v1_get\|layer_surface\|wl_output" "$DIR"/*.c | head -25

echo "=== output handling (registry)"
grep -n "wl_output" "$DIR"/*.c | head -20

echo "=== option parsing area"
grep -n "getopt\|long_options\|struct option" "$DIR/main.c" | head -10
