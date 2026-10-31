#!/bin/sh
# Build InputPlumber 0.82.0 with the axis-to-wheel patch and a saner source
# poll rate. The upstream source loop sleeps 2.5 ms between non-blocking reads
# per source (400 Hz), which measured ~11 % of a core at idle for two sources
# and identical load with the stock binary.
set -u

cd /root
rm -rf ip-src ip.tar.gz
curl -fsSL https://github.com/ShadowBlip/InputPlumber/archive/refs/tags/v0.82.0.tar.gz -o ip.tar.gz || exit 1
mkdir -p ip-src
tar xf ip.tar.gz -C ip-src --strip-components=1 || exit 1

cd ip-src
echo "=== applying axis-to-wheel patch"
patch -p1 < /root/0001-axis-to-wheel.patch || exit 1

echo "=== source poll rate 2.5 ms -> 4 ms (400 Hz -> 250 Hz)"
sed -i 's/const POLL_RATE: Duration = Duration::from_micros(2500);/const POLL_RATE: Duration = Duration::from_micros(4000);/' src/input/source/mod.rs
grep -n "const POLL_RATE" src/input/source/mod.rs

echo "=== toolchain"
cargo --version
rustc --version

echo "=== building (this takes a while)"
cargo build --release >/tmp/ip-build.log 2>&1
echo "build exit=$?"
tail -5 /tmp/ip-build.log
ls -l target/release/inputplumber 2>&1
