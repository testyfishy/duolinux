#!/bin/bash
# Extend the arm64 cross sysroot with the development packages a target build
# needs, without bootstrapping a rootfs and without qemu.
#
# The packages are downloaded for arm64 from Debian trixie, then unpacked with
# dpkg-deb -x. apt computes the dependency closure with an empty dpkg status,
# so nothing installed on the host leaks into the sysroot.
#
# Usage: setup-sysroot.sh [extra packages...]
#   wsl -d Ubuntu-26.04 -u root bash toolkit/cross/setup-sysroot.sh
set -euo pipefail

SYSROOT=${SYSROOT:-/srv/duo-arm64-sysroot}
DEBS=${DEBS:-/srv/duo-arm64-debs}
LIST=/tmp/duo-arm64-sources.list

PKGS=(
    # wvkbd: wayland-client, xkbcommon, pangocairo
    libwayland-dev libwayland-client0 libwayland-server0 libwayland-cursor0
    libxkbcommon-dev libxkbcommon0
    libpango1.0-dev libpangocairo-1.0-0 libpango-1.0-0 libpangoft2-1.0-0
    libcairo2-dev libcairo2 libcairo-gobject2
    libglib2.0-dev libglib2.0-0t64
    libfontconfig-dev libfontconfig1 libfreetype-dev libfreetype6
    libpng-dev libpng16-16t64 libpixman-1-dev libpixman-1-0
    libfribidi0 libthai0 libdatrie1 libgraphite2-3 libharfbuzz0b
    libx11-dev libx11-6 libxcb1-dev libxcb1 libxcb-render0 libxcb-shm0
    libxext-dev libxext6 libxrender-dev libxrender1
    libwayland-bin
    # misc that target utilities commonly need
    libudev-dev libdbus-1-dev libiio-dev
    "${@}"
)

mkdir -p "$DEBS" "$SYSROOT"

if [ ! -s "$LIST" ]; then
    cat > "$LIST" <<'EOF'
deb [arch=arm64 trusted=yes] http://deb.debian.org/debian trixie main
deb [arch=arm64 trusted=yes] http://deb.debian.org/debian trixie-updates main
EOF
fi

apt_opts=(
    -o "Dir::Etc::sourcelist=$LIST"
    -o "Dir::Etc::sourceparts=/dev/null"
    -o "Dir::State::status=/dev/null"
    -o "APT::Architecture=arm64"
    -o "APT::Architectures::=arm64"
)

echo "=== updating arm64 indexes"
apt-get "${apt_opts[@]}" update -qq 2>&1 | tail -2

echo "=== downloading ${#PKGS[@]} arm64 packages"
cd "$DEBS"
apt-get "${apt_opts[@]}" install -y --download-only \
    -o "Dir::Cache::archives=$DEBS" "${PKGS[@]}" >/tmp/duo-sysroot-dl.log 2>&1 || {
        tail -15 /tmp/duo-sysroot-dl.log; exit 1; }

echo "=== extracting"
n=0
for deb in ./*.deb; do
    [ -f "$deb" ] || continue
    dpkg-deb -x "$deb" "$SYSROOT" && n=$((n + 1))
done
echo "  unpacked $n debs into $SYSROOT"

# wayland-protocols is architecture-independent XML; take it from the host if
# it is there, so cross builds can generate protocol code.
if [ -d /usr/share/wayland-protocols ]; then
    mkdir -p "$SYSROOT/usr/share"
    rm -rf "$SYSROOT/usr/share/wayland-protocols"
    cp -r /usr/share/wayland-protocols "$SYSROOT/usr/share/"
    echo "  wayland-protocols: $(ls "$SYSROOT/usr/share/wayland-protocols" | tr '\n' ' ')"
fi

echo "=== verification"
PC="$SYSROOT/usr/lib/aarch64-linux-gnu/pkgconfig"
for p in wayland-client xkbcommon pangocairo cairo pango; do
    printf '  %-16s ' "$p"
    if PKG_CONFIG_SYSROOT_DIR="$SYSROOT" PKG_CONFIG_LIBDIR="$PC" pkg-config --modversion "$p" 2>/dev/null; then
        :
    else
        echo MISSING
    fi
done
du -sh "$SYSROOT"
