#!/bin/bash
# Cross-build the patched wvkbd (uinput-capable on-screen keyboard) on the PC.
#
# The source is the exact tree that was built on the handheld, so the binary is
# behaviourally identical; only the compiler changes. Uses the arm64 sysroot
# from setup-sysroot.sh.
#
# Usage: wsl -d Ubuntu-26.04 bash toolkit/cross/build-wvkbd.sh [srcdir]
set -euo pipefail

SRC=${1:-$HOME/builds/wvkbd}
SYSROOT=${SYSROOT:-/srv/duo-arm64-sysroot}
OUT=${OUT:-$HOME/builds/out}

[ -f "$SRC/Makefile" ] || { echo "no source tree at $SRC (scp /root/wvkbd-0.15 first)" >&2; exit 1; }
[ -d "$SYSROOT/usr/lib/aarch64-linux-gnu" ] || { echo "no sysroot at $SYSROOT" >&2; exit 1; }

export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"
export PKG_CONFIG_LIBDIR="$SYSROOT/usr/lib/aarch64-linux-gnu/pkgconfig:$SYSROOT/usr/share/pkgconfig"
export CC=aarch64-linux-gnu-gcc
export CFLAGS="-O2 -march=armv8-a -fno-plt"
# The sysroot's .so.6 files are absolute symlinks (/lib/aarch64-linux-gnu/...),
# so ld must be told to look inside the sysroot when following them.
export LDFLAGS="-Wl,--as-needed -Wl,--sysroot=$SYSROOT"

echo "=== toolchain"
aarch64-linux-gnu-gcc --version | head -1
wayland-scanner --version 2>&1 | head -1

echo "=== deps seen through the sysroot"
pkg-config --modversion wayland-client xkbcommon pangocairo

cd "$SRC"
make clean >/dev/null 2>&1 || true
rm -f ./*.o proto/*.o

echo "=== build"
make -j"$(nproc)" LAYOUT=mobintl >/tmp/wvkbd-cross.log 2>&1 || {
    tail -30 /tmp/wvkbd-cross.log; exit 1; }

mkdir -p "$OUT"
cp wvkbd-mobintl "$OUT/wvkbd-mobintl"
aarch64-linux-gnu-strip "$OUT/wvkbd-mobintl"

echo "=== artefact"
ls -l "$OUT/wvkbd-mobintl"
file "$OUT/wvkbd-mobintl"
echo "  linked against:"
aarch64-linux-gnu-readelf -d "$OUT/wvkbd-mobintl" | sed -n 's/.*Shared library: \[\(.*\)\]/    \1/p'
