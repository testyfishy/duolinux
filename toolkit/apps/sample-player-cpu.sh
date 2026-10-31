#!/bin/sh
# Sample CPU during playback for 3 minutes; read the log afterwards.
set -u
LOG=/tmp/player-cpu.log
: > "$LOG"
echo "time  player  cpu%" >> "$LOG"
i=0
while [ $i -lt 90 ]; do
    for p in $(pgrep -f "tsukimi|mpv" 2>/dev/null); do
        c=$(ps -o %cpu= -p "$p" 2>/dev/null | tr -d ' ')
        n=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | awk '{print $1}' | xargs -r basename 2>/dev/null)
        [ -n "$c" ] && echo "$(date +%H:%M:%S) $n $c" >> "$LOG"
    done
    i=$((i + 1))
    sleep 2
done
