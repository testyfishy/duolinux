#!/bin/bash
# Probe the device once a second from the host and log reachability.
# A real suspend makes every probe fail for the whole sleep window.
H=192.168.86.33
LOG=$HOME/lidmon.txt
: > "$LOG"
for i in $(seq 1 300); do
    if ping -c1 -W1 "$H" >/dev/null 2>&1; then s=up; else s=DOWN; fi
    printf '%s %s\n' "$(date +%H:%M:%S)" "$s" >> "$LOG"
    sleep 1
done
