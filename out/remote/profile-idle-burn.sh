#!/bin/sh
# Find out what the idle CPU burn actually is.
set -u

echo "=== inputplumber threads (20 s, last sample)"
top -H -b -d 20 -n 2 -p 462 2>/dev/null | awk '/^top -/{n++} n==2' | sed -n '1,12p'

echo "=== inputplumber syscalls over 5 s"
timeout 6 strace -c -f -p 462 2>&1 | tail -12

echo "=== duo-backkey syscalls over 5 s"
timeout 6 strace -c -f -p 833 2>&1 | tail -10

echo "=== duo-fan syscalls over 5 s"
timeout 6 strace -c -f -p 877 2>&1 | tail -10

echo "=== what duo-backkey does (top-level loop)"
grep -nE "sleep|poll|select|read|open" /usr/local/bin/duo-backkey | head -25

echo "=== what duo-fan polls"
grep -nE "sleep|poll|time.sleep|interval|INTERVAL" /usr/local/bin/duo-fan | head -20

echo "=== inputplumber config"
grep -nE "poll|interval|sample|rate" /etc/inputplumber/config.yaml 2>/dev/null | head -10
ls -l /etc/inputplumber/ 2>/dev/null
