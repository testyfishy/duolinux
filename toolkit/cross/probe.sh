#!/bin/bash
# Probe the WSL host for what is needed to cross-build arm64 Rust binaries.
set -u

echo "=== toolchain"
for b in cargo rustc rustup aarch64-linux-gnu-gcc pkg-config mmdebstrap qemu-aarch64-static; do
    printf '%s: %s\n' "$b" "$(command -v "$b" || echo missing)"
done

echo "=== rust"
rustc --version 2>/dev/null || echo "no rustc"
rustup target list --installed 2>/dev/null || echo "no rustup targets"
grep -E '^name|^channel' "$HOME/.rustup/settings.toml" 2>/dev/null | head -3

echo "=== arm64 sysroot"
ls -d /usr/aarch64-linux-gnu 2>/dev/null || echo "no /usr/aarch64-linux-gnu"
ls /usr/aarch64-linux-gnu/lib/libdbus-1.so* 2>/dev/null | head -2
ls /usr/aarch64-linux-gnu/lib/libudev.so* 2>/dev/null | head -2

echo "=== multiarch"
dpkg --print-foreign-architectures 2>/dev/null || true
apt-cache policy libdbus-1-dev:arm64 2>/dev/null | head -3

echo "=== pkgconf"
ls /usr/lib/aarch64-linux-gnu/pkgconfig/dbus-1.pc 2>/dev/null || echo "no arm64 dbus pkgconfig"
