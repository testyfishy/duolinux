#!/bin/bash
# One-time setup: arm64 cross toolchain + Rust target + an arm64 sysroot with
# the libraries InputPlumber links against.
set -u

echo "=== identity"
id -u
command -v sudo >/dev/null && echo "sudo: present" || echo "sudo: missing"

echo "=== apt update"
sudo -n apt-get update -qq 2>&1 | tail -2 || apt-get update -qq 2>&1 | tail -2

echo "=== cross toolchain + build deps"
sudo -n apt-get install -y -qq gcc-aarch64-linux-gnu libc6-dev-arm64-cross \
    pkg-config curl clang libclang-dev >/tmp/apt-cross.log 2>&1 || \
  apt-get install -y -qq gcc-aarch64-linux-gnu libc6-dev-arm64-cross \
    pkg-config curl clang libclang-dev >/tmp/apt-cross.log 2>&1
echo "apt exit=$?"
aarch64-linux-gnu-gcc --version | head -1

echo "=== rustup"
if ! command -v cargo >/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o /tmp/rustup.sh
    sh /tmp/rustup.sh -y --profile minimal --default-toolchain stable >/tmp/rustup.log 2>&1
    echo "rustup exit=$?"
fi
export PATH="$HOME/.cargo/bin:$PATH"
cargo --version || { echo "cargo install failed"; tail -5 /tmp/rustup.log; exit 1; }
rustup target add aarch64-unknown-linux-gnu 2>&1 | tail -2

echo "=== arm64 sysroot (Debian trixie)"
if [ ! -d /srv/duo-arm64-sysroot/usr/lib/aarch64-linux-gnu ]; then
    sudo -n mmdebstrap --variant=minbase --architectures=arm64 \
        --include=libdbus-1-dev,libudev-dev,libiio-dev,pkg-config \
        trixie /srv/duo-arm64-sysroot >/tmp/mmdeb.log 2>&1 || \
    sudo mmdebstrap --variant=minbase --architectures=arm64 \
        --include=libdbus-1-dev,libudev-dev,libiio-dev,pkg-config \
        trixie /srv/duo-arm64-sysroot >/tmp/mmdeb.log 2>&1
    echo "mmdebstrap exit=$?"
fi
ls /srv/duo-arm64-sysroot/usr/lib/aarch64-linux-gnu/libdbus-1.so* 2>/dev/null | head -2
ls /srv/duo-arm64-sysroot/usr/lib/aarch64-linux-gnu/pkgconfig/ 2>/dev/null | head -5
