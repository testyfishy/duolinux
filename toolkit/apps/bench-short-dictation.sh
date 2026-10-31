#!/bin/sh
# Realistic dictation latency: a ~3 s utterance, the length people actually
# speak, at several thread counts.
set -u
CLI=/opt/duo-stt/whisper.cpp/build/bin/whisper-cli
M=/opt/duo-stt/models/ggml-tiny.en.bin
SRC=/opt/duo-stt/models/sherpa-onnx-whisper-tiny.en/test_wavs/0.wav

ffmpeg -hide_banner -loglevel error -y -i "$SRC" -ss 0 -t 3 /tmp/short.wav
echo "clip: $(ffprobe -hide_banner /tmp/short.wav 2>&1 | grep -oE 'Duration: [0-9:.]+' | head -1)"

for t in 4 8; do
    line=$(nice -n 5 "$CLI" -m "$M" -f /tmp/short.wav -t "$t" -nt 2>&1 | \
        grep -E "total time|^\[" | tail -3)
    echo "=== threads=$t"
    echo "$line" | sed 's/^/  /'
done
