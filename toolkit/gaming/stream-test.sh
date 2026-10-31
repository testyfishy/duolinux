#!/bin/sh
# Measure a real stream at a given resolution, then read the stats Moonlight logs.
set -u
HOST="${1:?usage: stream-test.sh <host> [app] [resolution] [fps] [kbps]}"
APP="${2:-Steam Big Picture}"
RES="${3:-1920x1080}"
FPS="${4:-60}"
BR="${5:-30000}"
SECS="${6:-60}"
LOG=/tmp/ml-stream.log

pkill -f "com.moonlight_stream.Moonlight" 2>/dev/null
sleep 2
: > "$LOG"

su - duo -c "HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 \
    timeout $SECS flatpak run com.moonlight_stream.Moonlight stream $HOST '$APP' \
    --resolution $RES --fps $FPS --bitrate $BR" >>"$LOG" 2>&1
rc=$?

echo "=== exit: $rc (124 = timeout, i.e. it streamed for the full window)"
echo
echo "=== performance statistics"
grep -aiE "fps|stats|dropped|frame|latency|bitrate|network" "$LOG" | tail -20
echo
echo "=== decoder and renderer"
grep -aiE "decoder chosen|renderer|hardware decoder|software decoder|VAAPI|Vulkan|FFmpeg-based" "$LOG" | tail -8
echo
echo "=== problems"
grep -aiE "error|fail|cannot|unable|timeout" "$LOG" | grep -av "portal.Settings" | tail -6
