#!/bin/bash
# Cross-build whisper.cpp (whisper-cli) for the handheld on the PC.
#
# Target is ARMv8.0-A with NEON and no dotprod/LSE, which is what SM6125 has.
# libstdc++ and libgcc are linked statically and OpenMP is off, so the only
# runtime dependency is glibc - and it comes from the Debian trixie sysroot,
# not from the Ubuntu cross toolchain, so the binary cannot ask for a newer
# GLIBC than the device has.
#
# Usage: wsl -d Ubuntu-26.04 bash toolkit/cross/build-whispercpp.sh
set -euo pipefail

SYSROOT=${SYSROOT:-/srv/duo-arm64-sysroot}
W=${W:-$HOME/builds/whispercpp}
SRC="$W/src"
OUT=${OUT:-$HOME/builds/out}

mkdir -p "$W" "$OUT"

if [ ! -d "$SRC/.git" ]; then
    echo "=== fetching whisper.cpp"
    rm -rf "$SRC"
    git clone --depth 1 https://github.com/ggml-org/whisper.cpp "$SRC" >/tmp/whisper-clone.log 2>&1 || {
        tail -5 /tmp/whisper-clone.log; exit 1; }
fi
echo "  commit: $(git -C "$SRC" rev-parse --short HEAD)"

cat > "$W/toolchain.cmake" <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)
set(CMAKE_SYSROOT $SYSROOT)
set(CMAKE_FIND_ROOT_PATH $SYSROOT)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
EOF

ARCH_FLAGS="-O3 -march=armv8-a -mtune=cortex-a73 -fno-plt"

echo "=== configure"
cmake -S "$SRC" -B "$SRC/build-aarch64" \
    -DCMAKE_TOOLCHAIN_FILE="$W/toolchain.cmake" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="$ARCH_FLAGS" \
    -DCMAKE_CXX_FLAGS="$ARCH_FLAGS" \
    -DCMAKE_EXE_LINKER_FLAGS="-static" \
    -DGGML_NATIVE=OFF \
    -DGGML_OPENMP=OFF \
    -DGGML_CPU_AARCH64=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_EXAMPLES=ON \
    >"$W/configure.log" 2>&1 || { tail -20 "$W/configure.log"; exit 1; }

echo "=== build"
cmake --build "$SRC/build-aarch64" -j"$(nproc)" --target whisper-cli \
    >"$W/build.log" 2>&1 || { tail -25 "$W/build.log"; exit 1; }

cp "$SRC/build-aarch64/bin/whisper-cli" "$OUT/whisper-cli"
aarch64-linux-gnu-strip "$OUT/whisper-cli"

echo "=== artefact"
ls -l "$OUT/whisper-cli"
file "$OUT/whisper-cli"
echo "  runtime deps:"
aarch64-linux-gnu-readelf -d "$OUT/whisper-cli" \
    | sed -n 's/.*Shared library: \[\(.*\)\]/    \1/p'
echo "  max glibc symbol:"
aarch64-linux-gnu-readelf --dyn-syms "$OUT/whisper-cli" \
    | sed -n 's/.*@GLIBC_\([0-9.]*\).*/\1/p' | sort -V | tail -1
