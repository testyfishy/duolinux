#!/bin/bash
# Prepare to build a patched InputPlumber: toolchain, system libs, and the
# source tree at the exact version the device is running (0.82.0).
set -u
export DEBIAN_FRONTEND=noninteractive
LOG=/var/log/inputplumber-build.log
exec >>"$LOG" 2>&1
echo "=== $(date) start"

apt-get -o Acquire::ForceIPv4=true install -y --no-install-recommends \
    cargo rustc build-essential pkg-config libudev-dev libdbus-1-dev git \
    libssl-dev 2>&1 | tail -5

echo "=== versions"
rustc --version
cargo --version

echo "=== source"
rm -rf /root/InputPlumber
git clone --depth 1 --branch v0.82.0 \
    https://github.com/ShadowBlip/InputPlumber /root/InputPlumber 2>&1 | tail -2
cd /root/InputPlumber || exit 1
git log --oneline -1

echo "=== does it parse without building?"
cargo metadata --no-deps --format-version 1 >/dev/null 2>&1 && echo "metadata ok" || echo "metadata failed"

echo "=== $(date) done"
