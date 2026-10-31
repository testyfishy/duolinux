#!/bin/bash
# Move whisper-server to 8090: 8080 is already taken by Tailscale Serve (HTTPS)
# and qBittorrent on localhost.
set -u
W=$HOME/whisper-server
LOG=/tmp/whisper-server.log
BIN=$W/src/build/bin/whisper-server
MODEL=$W/ggml-base.en.bin
PORT=8090

pkill -x whisper-server 2>/dev/null
sleep 1

setsid nohup "$BIN" -m "$MODEL" --host 0.0.0.0 --port "$PORT" \
    --inference-path /v1/audio/transcriptions -t 8 \
    >"$LOG" 2>&1 < /dev/null &
sleep 6

echo "=== listening"
ss -ltn 2>/dev/null | grep ":${PORT}" || echo "  nothing on ${PORT}"
echo "=== local check"
curl -s -o /dev/null -w "  http=%{http_code}\n" "http://127.0.0.1:${PORT}/"
echo "  wsl ip: $(hostname -I | awk '{print $1}')"
