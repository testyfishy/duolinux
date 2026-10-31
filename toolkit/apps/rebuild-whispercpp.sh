#!/bin/bash
# Rebuild whisper.cpp politely: low priority, two jobs, so playback is not
# affected. Resumes the existing build directory.
set -u
B=/opt/duo-stt/whisper.cpp
LOG=/tmp/whispercpp-build.log
: >>"$LOG"

cd "$B" || exit 1
nice -n 19 cmake --build build -j2 --target whisper-cli >>"$LOG" 2>&1
rc=$?
echo "build rc=$rc"
ls -l "$B/build/bin/whisper-cli" 2>/dev/null | awk '{print "  binary:", $5, "bytes"}'

if [ -x "$B/build/bin/whisper-cli" ]; then
    M=/opt/duo-stt/models/ggml-tiny.en.bin
    WAV=/opt/duo-stt/models/sherpa-onnx-whisper-tiny.en/test_wavs/0.wav
    echo "=== transcribe (low priority, 4 threads)"
    nice -n 19 "$B/build/bin/whisper-cli" -m "$M" -f "$WAV" -t 4 -nt 2>&1 | tail -5
fi
