#!/bin/bash
# Decisive test: whisper.cpp (no ONNX Runtime) on the same clip.
set -u
B=/opt/duo-stt/whisper.cpp
LOG=/tmp/whispercpp-build.log
: > "$LOG"

echo "=== toolchain" | tee -a "$LOG"
for t in gcc g++ make cmake git; do echo "  $t: $(command -v $t || echo missing)" | tee -a "$LOG"; done

if [ ! -d "$B" ]; then
    echo "=== fetching source" | tee -a "$LOG"
    mkdir -p /opt/duo-stt
    curl -sL -o /tmp/whisper.cpp.tar.gz \
        https://github.com/ggml-org/whisper.cpp/archive/refs/heads/master.tar.gz >>"$LOG" 2>&1
    tar xzf /tmp/whisper.cpp.tar.gz -C /opt/duo-stt >>"$LOG" 2>&1
    mv /opt/duo-stt/whisper.cpp-master "$B" 2>/dev/null || true
fi

echo "=== building" | tee -a "$LOG"
cd "$B"
cmake -B build -DCMAKE_BUILD_TYPE=Release -DWHISPER_BUILD_TESTS=OFF >>"$LOG" 2>&1
cmake --build build -j"$(nproc)" --target whisper-cli >>"$LOG" 2>&1
echo "  build rc=$? binary: $(ls -l "$B/build/bin/whisper-cli" 2>/dev/null | awk '{print $5}') bytes" | tee -a "$LOG"

echo "=== model" | tee -a "$LOG"
M=/opt/duo-stt/models/ggml-tiny.en.bin
[ -f "$M" ] || curl -sL -o "$M" https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin
echo "  $(du -h "$M" 2>/dev/null | cut -f1)" | tee -a "$LOG"

echo "=== transcribe" | tee -a "$LOG"
WAV=/opt/duo-stt/models/sherpa-onnx-whisper-tiny.en/test_wavs/0.wav
/usr/bin/env time -f "  wall %e s" "$B/build/bin/whisper-cli" -m "$M" -f "$WAV" -t 4 -nt 2>&1 | tail -6 | tee -a "$LOG"
