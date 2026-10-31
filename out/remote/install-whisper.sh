#!/bin/bash
# Build whisper.cpp on the device and fetch a small English model, then time it
# on the bundled JFK sample. Runs in the background; logs to /var/log/whisper-install.log
set -u
export DEBIAN_FRONTEND=noninteractive
LOG=/var/log/whisper-install.log
exec >>"$LOG" 2>&1
echo "=== $(date) start"

apt-get -o Acquire::ForceIPv4=true install -y --no-install-recommends \
    cmake build-essential git libopenblas0-pthread curl 2>&1 | tail -3

rm -rf /root/whisper.cpp
git clone --depth 1 https://github.com/ggml-org/whisper.cpp /root/whisper.cpp 2>&1 | tail -2
cd /root/whisper.cpp || exit 1

cmake -B build -DCMAKE_BUILD_TYPE=Release -DWHISPER_OPENBLAS=ON 2>&1 | tail -3
cmake --build build -j4 2>&1 | tail -5

echo "=== fetching model base.en (q5 quantised)"
mkdir -p /usr/share/whisper
curl -L --fail -o /usr/share/whisper/ggml-base.en-q5_1.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en-q5_1.bin 2>&1 | tail -1
ls -lh /usr/share/whisper/

echo "=== timing on the bundled sample"
/usr/bin/time -v ./build/bin/whisper-cli -m /usr/share/whisper/ggml-base.en-q5_1.bin \
    -f samples/jfk.wav -nt -np 2>&1 | grep -E "^\[|Elapsed|User time|Maximum resident" | head -12

echo "=== $(date) done"
