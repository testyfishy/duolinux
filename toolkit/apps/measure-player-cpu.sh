#!/bin/sh
# Who is consuming CPU right now, and is a player running?
set -u
echo "=== media processes"
ps -eo pid,pcpu,pmem,etime,comm 2>/dev/null | grep -iE "tsukimi|mpv|jellyfin|QtWebEngine" | grep -v grep | sed 's/^/  /'

echo
echo "=== top cpu"
ps -eo pcpu,comm --sort=-pcpu 2>/dev/null | head -8 | sed 's/^/  /'

echo
echo "=== load"
cut -d' ' -f1-3 /proc/loadavg | sed 's/^/  /'

echo
echo "=== network (is video flowing?)"
r1=$(cat /sys/class/net/wlan0/statistics/rx_bytes)
sleep 4
r2=$(cat /sys/class/net/wlan0/statistics/rx_bytes)
echo "  rx: $(( (r2 - r1) * 8 / 4 / 1000000 )) Mbit/s"

echo
echo "=== windows on screen"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 kdotool search --name "" 2>/dev/null' >/dev/null 2>&1 \
  && echo "  (kdotool available)" || echo "  kdotool not installed"
