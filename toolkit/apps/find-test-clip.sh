#!/bin/sh
set -u
M=/opt/duo-stt/models/sherpa-onnx-moonshine-tiny-en-int8
echo "=== model files"
ls -lh "$M" | sed 's/^/  /'

echo
echo "=== test wav candidates"
for u in \
  https://github.com/k2-fsa/sherpa-onnx/raw/master/test_wavs/0.wav \
  https://github.com/k2-fsa/sherpa-onnx/raw/master/test_wavs/en.wav \
  https://github.com/k2-fsa/sherpa-onnx/raw/master/test_wavs/1.wav ; do
    code=$(curl -sL -o /tmp/probe.wav -w '%{http_code}' --max-time 20 "$u")
    size=$(stat -c %s /tmp/probe.wav 2>/dev/null || echo 0)
    echo "  $code $size  $u"
    if [ "$code" = 200 ] && [ "$size" -gt 10000 ]; then cp /tmp/probe.wav /tmp/speech.wav; break; fi
done
[ -f /tmp/speech.wav ] && ffprobe -hide_banner /tmp/speech.wav 2>&1 | grep -E "Duration|Audio" | sed 's/^/  /'
