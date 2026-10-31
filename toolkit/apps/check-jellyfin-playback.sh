#!/bin/sh
# While Jellyfin is playing: who is working, and how hard?
set -u
echo "=== jellyfin processes"
ps -eo pid,pcpu,pmem,etime,args 2>/dev/null | grep -iE "jellyfin|mpv|moonlight" | grep -v grep | cut -c1-110 | sed 's/^/  /'

echo
echo "=== cpu load (1 min) and per-core busy"
uptime | sed 's/^/  /'
echo "  busiest:"; ps -eo pcpu,comm --sort=-pcpu 2>/dev/null | head -6 | sed 's/^/    /'

echo
echo "=== network throughput now"
IFACE=wlan0
r1=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
sleep 3
r2=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
echo "  rx: $(( (r2 - r1) * 8 / 3 / 1000000 )) Mbit/s"
echo "  link: $(iw dev $IFACE link 2>/dev/null | grep -E 'signal|bitrate' | tr '\n' ' ')"

echo
echo "=== playback libraries actually in use"
for p in $(pgrep -f "jellyfin|mpv" 2>/dev/null); do
    echo "  pid $p: $(tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null | cut -c1-90)"
done
