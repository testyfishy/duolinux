#!/bin/bash
# Root half of the cross-build setup, without chroot or qemu.
#
# The arm64 sysroot only needs headers, .so symlinks and pkg-config files, so
# the arm64 .debs are extracted with dpkg-deb instead of bootstrapping a
# rootfs. That avoids binfmt/qemu entirely, which WSL2 does not provide here.
set -u

echo "=== apt update"
apt-get update -qq 2>&1 | tail -2

echo "=== host cross toolchain"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    gcc-aarch64-linux-gnu libc6-dev-arm64-cross pkg-config curl \
    clang libclang-dev >/tmp/apt-root.log 2>&1
echo "apt exit=$?"
tail -3 /tmp/apt-root.log
aarch64-linux-gnu-gcc --version 2>/dev/null | head -1

echo "=== arm64 sysroot from Debian trixie"
SYSROOT=/srv/duo-arm64-sysroot
DEBS=/srv/duo-arm64-debs
mkdir -p "$DEBS"
dpkg --add-architecture arm64 2>/dev/null || true
cat > /tmp/arm64-sources.list <<'EOF'
deb [arch=arm64 trusted=yes] http://deb.debian.org/debian trixie main
EOF

apt-get -o Dir::Etc::sourcelist=/tmp/arm64-sources.list \
        -o Dir::Etc::sourceparts=/dev/null \
        -o APT::Architecture=arm64 update >/tmp/apt-arm64-update.log 2>&1
echo "arm64 index exit=$?"

cd "$DEBS" || exit 1
apt-get -o Dir::Etc::sourcelist=/tmp/arm64-sources.list \
        -o Dir::Etc::sourceparts=/dev/null \
        -o APT::Architecture=arm64 download \
        libdbus-1-dev:arm64 libdbus-1-3:arm64 libudev-dev:arm64 libudev1:arm64 \
        libiio-dev:arm64 libiio0:arm64 \
        >/tmp/apt-arm64-download.log 2>&1
echo "download exit=$?"
ls -1 *.deb 2>/dev/null | head -8

mkdir -p "$SYSROOT"
for deb in ./*.deb; do
    [ -f "$deb" ] || continue
    dpkg-deb -x "$deb" "$SYSROOT"
done

echo "=== sysroot contents"
ls "$SYSROOT"/usr/lib/aarch64-linux-gnu/libdbus-1.so* 2>/dev/null | head -2
ls "$SYSROOT"/usr/lib/aarch64-linux-gnu/pkgconfig/ 2>/dev/null | head -6
ls "$SYSROOT"/usr/include/dbus-1.0/dbus/dbus.h 2>/dev/null
