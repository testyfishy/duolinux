#!/bin/sh
# Fetch Moonshine tiny (int8) and time it on a known clip, on the big cores.
set -u
V=/opt/duo-stt/venv
M=/opt/duo-stt/models
mkdir -p "$M"
cd "$M"

echo "=== available CLI tools"
ls "$V/bin" | grep -i sherpa | sed 's/^/  /'

echo
echo "=== model"
if [ ! -d "$M/sherpa-onnx-moonshine-tiny-en-int8" ]; then
    curl -sL -o moonshine.tar.bz2 \
      https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-moonshine-tiny-en-int8.tar.bz2 \
      && tar xjf moonshine.tar.bz2 && rm -f moonshine.tar.bz2
fi
ls -la "$M/sherpa-onnx-moonshine-tiny-en-int8" 2>/dev/null | head -6 | sed 's/^/  /'
du -sh "$M/sherpa-onnx-moonshine-tiny-en-int8" 2>/dev/null | sed 's/^/  size: /'

echo
echo "=== test clip"
[ -f /tmp/0.wav ] || curl -sL -o /tmp/0.wav \
  https://github.com/k2-fsa/sherpa-onnx/raw/master/test_wavs/0.wav
ffprobe -hide_banner /tmp/0.wav 2>&1 | grep -E "Duration|Stream" | sed 's/^/  /'

echo
echo "=== which cores are the big ones"
lscpu -e 2>/dev/null | awk 'NR==1 || $4 ~ /^[0-9]+$/ {print "  "$0}' | head -10

echo
echo "=== timed run (4 threads)"
/usr/bin/time -f "  wall %e s (user %U s)" \
  "$V/bin/sherpa-onnx-offline" \
    --tokens="$M/sherpa-onnx-moonshine-tiny-en-int8/tokens.txt" \
    --encoder="$M/sherpa-onnx-moonshine-tiny-en-int8/encoder_model.int8.onnx" \
    --decoder="$M/sherpa-onnx-moonshine-tiny-en-int8/decoder_model.int8.onnx" \
    --num-threads=4 \
    /tmp/0.wav 2>&1 | tail -6
