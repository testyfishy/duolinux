#!/bin/bash
# Cross-build InputPlumber for the handheld on the HTPC (WSL).
#
# Building on the device ties up the handheld for ~15 minutes for no benefit:
# the binary is aarch64, the compiler does not need the hardware, and the only
# host-specific inputs are the shared libraries it links against. Those come
# from an arm64 sysroot built by setup-root.sh.
#
# Usage:
#   wsl -d Ubuntu-26.04 bash "<repo>/toolkit/cross/build-inputplumber.sh"
#
# Output: out/build/inputplumber  (push with toolkit/cross/deploy.sh)
set -euo pipefail

export PATH="$HOME/.cargo/bin:$PATH"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SYSROOT=/srv/duo-arm64-sysroot
WORK="$HOME/duo-build/inputplumber"
VERSION=0.82.0
TARGET=aarch64-unknown-linux-gnu

if [ ! -f "$SYSROOT/usr/lib/aarch64-linux-gnu/libdbus-1.so" ]; then
    echo "missing arm64 sysroot: run toolkit/cross/setup-root.sh first" >&2
    exit 1
fi
if ! command -v cargo >/dev/null; then
    echo "missing cargo: run toolkit/cross/setup-rust.sh first" >&2
    exit 1
fi

mkdir -p "$WORK"
if [ ! -d "$WORK/src" ]; then
    cd "$WORK"
    curl -fsSL "https://github.com/ShadowBlip/InputPlumber/archive/refs/tags/v${VERSION}.tar.gz" -o ip.tar.gz
    mkdir -p src
    tar xf ip.tar.gz -C src --strip-components=1
    cd src
    for patch_file in "$REPO"/out/inputplumber-fork/000*.patch; do
        echo "applying $(basename "$patch_file")"
        patch -p1 < "$patch_file"
    done
fi

cd "$WORK/src"

export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
export PKG_CONFIG_ALLOW_CROSS=1
export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"
export PKG_CONFIG_LIBDIR="$SYSROOT/usr/lib/aarch64-linux-gnu/pkgconfig:$SYSROOT/usr/share/pkgconfig"
export BINDGEN_EXTRA_CLANG_ARGS="--sysroot=$SYSROOT -I$SYSROOT/usr/include -I$SYSROOT/usr/include/aarch64-linux-gnu"
export RUSTFLAGS="-C link-arg=-L$SYSROOT/usr/lib/aarch64-linux-gnu -C link-arg=-Wl,-rpath-link,$SYSROOT/usr/lib/aarch64-linux-gnu"
# crates that compile C (hidapi) need the arm64 headers, not the host's.
# cc-rs reads the underscore form of the target in the variable name.
export CFLAGS_aarch64_unknown_linux_gnu="-I$SYSROOT/usr/include -I$SYSROOT/usr/include/aarch64-linux-gnu"
export CXXFLAGS_aarch64_unknown_linux_gnu="$CFLAGS_aarch64_unknown_linux_gnu"
export CC_aarch64_unknown_linux_gnu=aarch64-linux-gnu-gcc

cargo build --release --locked --target "$TARGET"

BIN="target/$TARGET/release/inputplumber"
file "$BIN"
mkdir -p "$REPO/out/build"
cp "$BIN" "$REPO/out/build/inputplumber"
ls -l "$REPO/out/build/inputplumber"
