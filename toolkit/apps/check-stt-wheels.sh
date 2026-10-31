#!/bin/sh
# Which candidate engines actually publish aarch64 wheels, and how recent?
set -u
for pkg in sherpa-onnx vosk faster-whisper; do
    echo "=== $pkg"
    curl -s --max-time 25 "https://pypi.org/simple/$pkg/" \
      | grep -oE '[^">/]+\.whl' \
      | grep -E 'aarch64|arm64' \
      | tail -4 | sed 's/^/  /'
    n=$(curl -s --max-time 25 "https://pypi.org/simple/$pkg/" | grep -c 'aarch64')
    echo "  aarch64 wheel count: $n"
done
