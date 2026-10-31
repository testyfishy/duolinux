#!/bin/sh
# What are the two polled sources, and does InputPlumber expose a poll interval?
set -u

echo "=== device names for the polled nodes"
awk '/^N: Name=/{name=$0} /^H: Handlers=/{h=$0; if (h ~ /event5|event6/) print name, h}' /proc/bus/input/devices

echo "=== inputplumber help, polling/source related"
/usr/local/bin/inputplumber --help 2>&1 | grep -iE "poll|interval|rate|source" | head -10

echo "=== recent device activity"
journalctl -u inputplumber --since '-20 min' --no-pager 2>&1 | grep -iE "added|source|hidraw|profile|manager" | tail -10

echo "=== which processes hold the touchscreen nodes"
for e in /dev/input/event5 /dev/input/event6; do
    echo "$e:"
    fuser -v "$e" 2>&1 | head -4
done
