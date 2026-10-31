#!/bin/bash
# Start whisper-server in WSL and verify it is listening.
set -u
W=$HOME/whisper-server
LOG=/tmp/whisper-server.log
BIN=$W/src/build/bin/whisper-server
MODEL=$W/ggml-base.en.bin

pkill -x whisper-server 2>/dev/null
sleep 1

setsid nohup "$BIN" -m "$MODEL" --host 0.0.0.0 --port 8080 \
    --inference-path /v1/audio/transcriptions -t 8 \
    >"$LOG" 2>&1 < /dev/null &
sleep 6

echo "=== log"
tail -6 "$LOG" 2>/dev/null

echo
echo "=== listening"
ss -ltn 2>/dev/null | grep -E "8080" || echo "  nothing on 8080"
echo "  wsl address: $(hostname -I 2>/dev/null | awk '{print $1}')"
echo "  process: $(pgrep -fc whisper-server)"
