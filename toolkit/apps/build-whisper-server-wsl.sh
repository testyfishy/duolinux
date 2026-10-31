#!/bin/bash
# Build whisper.cpp natively (x86_64) in WSL on the HTPC and stage whisper-server
# plus a good English model. This becomes the default dictation engine.
set -euo pipefail
W=$HOME/whisper-server
SRC=$W/src
mkdir -p "$W"

if [ ! -d "$SRC" ]; then
    echo "=== fetching whisper.cpp"
    mkdir -p "$SRC"
    curl -sL -o /tmp/whispercpp-src.tar.gz \
        https://github.com/ggml-org/whisper.cpp/archive/refs/heads/master.tar.gz
    tar xzf /tmp/whispercpp-src.tar.gz -C "$SRC" --strip-components=1
fi

echo "=== configuring"
cd "$SRC"
cmake -B build -DCMAKE_BUILD_TYPE=Release -DWHISPER_BUILD_TESTS=OFF >"$W/configure.log" 2>&1 || {
    tail -15 "$W/configure.log"; exit 1; }

echo "=== building (16 cores)"
cmake --build build -j"$(nproc)" --target whisper-server whisper-cli >"$W/build.log" 2>&1 || {
    tail -20 "$W/build.log"; exit 1; }

ls -l build/bin/whisper-server build/bin/whisper-cli

echo "=== model"
M=$W/ggml-base.en.bin
if [ ! -f "$M" ]; then
    curl -sL -o "$M" https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
fi
du -h "$M"
echo "=== ready"
