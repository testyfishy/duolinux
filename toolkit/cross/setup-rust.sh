#!/bin/bash
# User half of the cross-build setup: Rust with the aarch64-linux-gnu target.
set -u

export PATH="$HOME/.cargo/bin:$PATH"

if ! command -v cargo >/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o /tmp/rustup.sh
    sh /tmp/rustup.sh -y --profile minimal --default-toolchain stable >/tmp/rustup.log 2>&1
    echo "rustup exit=$?"
fi

cargo --version || { echo "cargo missing"; tail -5 /tmp/rustup.log 2>/dev/null; exit 1; }
rustup target add aarch64-unknown-linux-gnu 2>&1 | tail -2
rustup target list --installed
