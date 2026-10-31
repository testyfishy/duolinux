#!/bin/bash
# Cross-compile whisper.cpp for the handheld on this HTPC (WSL), so the device
# only ever runs a binary. Target: ARMv8.0 + NEON, no dotprod.
set -euo pipefail
W=$HOME/whispercpp-cross
SRC=$W/src
BIN=$W/bin
mkdir -p "$W" "$BIN"

echo "=== toolchain"
for t in cmake aarch64-linux-gnu-gcc aarch64-linux-gnu-g++ aarch64-linux-gnu-strip; do
    command -v "$t" >/dev/null || { echo "installing missing tools"; sudo apt-get install -y -qq cmake g++-aarch64-linux-gnu binutils-aarch64-linux-gnu >/dev/null 2>&1; break; }
done
cmake --version | head -1
aarch64-linux-gnu-g++ --version | head -1

if [ ! -d "$SRC" ]; then
    echo "=== fetching whisper.cpp"
    mkdir -p "$SRC"
    curl -sL -o /tmp/whispercpp.tar.gz \
        https://github.com/ggml-org/whisper.cpp/archive/refs/heads/master.tar.gz
    tar xzf /tmp/whispercpp.tar.gz -C "$SRC" --strip-components=1
fi
echo "  source: $(ls "$SRC" | head -3 | tr '\n' ' ')"

cat > "$W/toolchain.cmake" <<'EOF'
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)
set(CMAKE_FIND_ROOT_PATH /usr/aarch64-linux-gnu)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF

echo "=== configure"
cd "$SRC"
cmake -B build-aarch64 \
    -DCMAKE_TOOLCHAIN_FILE="$W/toolchain.cmake" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="-O3 -march=armv8-a" \
    -DCMAKE_CXX_FLAGS="-O3 -march=armv8-a" \
    -DGGML_NATIVE=OFF \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_EXAMPLES=ON \
    > "$W/configure.log" 2>&1 || { tail -20 "$W/configure.log"; exit 1; }

echo "=== build"
cmake --build build-aarch64 -j"$(nproc)" --target whisper-cli > "$W/build.log" 2>&1 \
    || { tail -20 "$W/build.log"; exit 1; }

cp build-aarch64/bin/whisper-cli "$BIN/whisper-cli"
aarch64-linux-gnu-strip "$BIN/whisper-cli"
echo "=== artefact"
ls -l "$BIN/whisper-cli"
file "$BIN/whisper-cli" 2>/dev/null || true
