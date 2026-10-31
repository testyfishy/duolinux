#!/bin/sh
# Are the test clips actually speech? And can a synthetic utterance transcribe?
set -u
M=/opt/duo-stt/models/sherpa-onnx-zipformer-en-2023-06-26
echo "=== expected transcripts shipped with the model"
cat "$M/test_wavs/trans.txt" 2>/dev/null | sed 's/^/  /'
cat /opt/duo-stt/models/sherpa-onnx-whisper-tiny.en/test_wavs/trans.txt 2>/dev/null | sed 's/^/  /'

echo
echo "=== is the audio really speech? first 100 ms energy profile"
ffmpeg -hide_banner -i "$M/test_wavs/0.wav" -af "astats=metadata=1:reset=1" -f null - 2>&1 \
  | grep -E "RMS level dB|Peak level dB" | head -4 | sed 's/^/  /'

echo
echo "=== speech synthesis available?"
for t in espeak-ng espeak flite pico2wave; do
    echo "  $t: $(command -v $t || echo no)"
done

echo
echo "=== if espeak-ng exists, make a clean test phrase"
if command -v espeak-ng >/dev/null 2>&1; then
    espeak-ng -w /tmp/tts.wav -s 150 "the quick brown fox jumps over the lazy dog"
    ffprobe -hide_banner /tmp/tts.wav 2>&1 | grep -E "Duration|Audio" | sed 's/^/  /'
fi
