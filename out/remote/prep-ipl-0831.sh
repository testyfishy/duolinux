#!/bin/bash
# Prepare to build a patched InputPlumber 0.83.1.
# Advisor notes: Debian's rustc 1.85 may be too old (ratatui 0.30), so use
# rustup stable. Build on-device needs swap because the fat-LTO link peaks
# around 2 GB and the machine has ~2 GB free.
set -u
export DEBIAN_FRONTEND=noninteractive
LOG=/var/log/ipl-build.log
exec >>"$LOG" 2>&1
echo "=== $(date) start"

apt-get -o Acquire::ForceIPv4=true install -y --no-install-recommends \
    build-essential pkg-config libudev-dev libclang-dev clang curl git \
    zram-tools ca-certificates 2>&1 | tail -3

echo "=== zram for the link step"
if [ -f /etc/default/zramswap ]; then
    sed -i 's/^#\?ALGO=.*/ALGO=zstd/' /etc/default/zramswap
    sed -i 's/^#\?PERCENT=.*/PERCENT=50/' /etc/default/zramswap
    systemctl restart zramswap 2>/dev/null || true
    swapon --show
fi

echo "=== rustup"
if [ ! -x /root/.cargo/bin/rustc ]; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
        sh -s -- -y --profile minimal --default-toolchain stable 2>&1 | tail -3
fi
. "$HOME/.cargo/env" 2>/dev/null || true
rustc --version
cargo --version

echo "=== source v0.83.1"
rm -rf /root/InputPlumber
git clone --depth 1 --branch v0.83.1 \
    https://github.com/ShadowBlip/InputPlumber /root/InputPlumber 2>&1 | tail -2
cd /root/InputPlumber || exit 1
git log --oneline -1
echo "=== $(date) ready for patching"
