#!/bin/sh
# Stop the background build so playback is measured without CPU contention.
set -u
pkill -f "cmake --build" 2>/dev/null
pkill -f "cc1plus" 2>/dev/null
pkill -f "gmake" 2>/dev/null
sleep 3

echo "compilers left: $(pgrep -c cc1plus 2>/dev/null || echo 0)"
echo "load: $(cut -d' ' -f1-3 /proc/loadavg)"

echo
echo "=== top cpu now"
ps -eo pcpu,comm --sort=-pcpu 2>/dev/null | head -6 | sed 's/^/  /'

echo
echo "=== jellyfin cpu"
ps -eo pid,pcpu,comm 2>/dev/null | grep -i jellyfin | grep -v grep | sed 's/^/  /'

echo
echo "=== network rate"
r1=$(cat /sys/class/net/wlan0/statistics/rx_bytes)
sleep 3
r2=$(cat /sys/class/net/wlan0/statistics/rx_bytes)
echo "  $(( (r2 - r1) * 8 / 3 / 1000000 )) Mbit/s"
echo "  link: $(iw dev wlan0 link 2>/dev/null | grep -E 'signal|bitrate' | tr '\n' ' ')"

echo
echo "=== build state"
ls -l /opt/duo-stt/whisper.cpp/build/bin/whisper-cli 2>/dev/null || echo "  not built (stopped)"
