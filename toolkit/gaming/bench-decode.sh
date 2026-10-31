#!/bin/bash
# Does this SoC software-decode a Moonlight-class stream fast enough?
# Measures decode throughput for the resolutions actually in play, not an estimate.
set -uo pipefail
D=/tmp/decode-bench
mkdir -p "$D"

echo "=== ffmpeg"
command -v ffmpeg >/dev/null || { echo "  installing"; DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ffmpeg >/dev/null 2>&1; }
ffmpeg -hide_banner -version 2>/dev/null | head -1

echo
echo "=== generating test clips (libx264, low complexity, 10 s)"
gen() {  # name  size  fps
    local f="$D/$1.mp4"
    [ -f "$f" ] && return 0
    ffmpeg -hide_banner -loglevel error -y \
        -f lavfi -i "testsrc2=size=$2:rate=$3:duration=10" \
        -c:v libx264 -preset ultrafast -tune zerolatency -g 60 -b:v 8M "$f" 2>/dev/null
    echo "  $1: $(stat -c %s "$f" 2>/dev/null) bytes"
}
gen 1080p60 1920x1080 60
gen 1080p30 1920x1080 30
gen 720p60  1280x720  60

echo
echo "=== decode benchmark (default threads = all 8 cores)"
for c in 1080p60 1080p30 720p60; do
    out=$(ffmpeg -hide_banner -benchmark -nostats -i "$D/$c.mp4" -f null - 2>&1 | grep -E "^bench:|frame=" | tail -2)
    utime=$(echo "$out" | sed -n 's/.*utime=\([0-9.]*\).*/\1/p')
    stime=$(echo "$out" | sed -n 's/.*stime=\([0-9.]*\).*/\1/p')
    rtime=$(echo "$out" | sed -n 's/.*rtime=\([0-9.]*\).*/\1/p')
    fps=$(ffmpeg -hide_banner -nostats -i "$D/$c.mp4" -f null - 2>&1 | grep -oE "fps=[0-9.]+" | tail -1 | cut -d= -f2)
    echo "  $c: ${fps:-?} fps decode | cpu ${utime:-?}s user + ${stime:-?}s sys over ${rtime:-?}s wall"
done

echo
echo "=== same at 4 threads (the big cores only, worst case)"
for c in 1080p60 720p60; do
    fps=$(ffmpeg -hide_banner -nostats -threads 4 -i "$D/$c.mp4" -f null - 2>&1 | grep -oE "fps=[0-9.]+" | tail -1 | cut -d= -f2)
    echo "  $c: ${fps:-?} fps with 4 threads"
done

echo
echo "=== per-frame cost"
for c in 1080p60 1080p30 720p60; do
    utime=$(ffmpeg -hide_banner -benchmark -nostats -i "$D/$c.mp4" -f null - 2>&1 | sed -n 's/.*utime=\([0-9.]*\).*/\1/p')
    frames=$([ "$c" = "1080p60" ] || [ "$c" = "720p60" ] && echo 600 || echo 300)
    echo "  $c: $(awk -v u="$utime" -v f="$frames" 'BEGIN{printf "%.2f ms/frame (single-core equivalent)", u*1000/f}')"
done
