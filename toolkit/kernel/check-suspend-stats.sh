#!/bin/sh
# Did the hardware actually sleep, how long, and what woke it?
set -u
echo "=== suspend statistics (authoritative)"
for f in /sys/power/suspend_stats/*; do
    echo "  $(basename "$f"): $(cat "$f" 2>/dev/null)"
done

echo
echo "=== kernel view, monotonic timestamps"
dmesg | grep -iE "suspend entry|suspend exit|PM: suspend|wakeup|Disabling non-boot|Enabling non-boot|psci" | tail -15

echo
echo "=== network during the suspend window"
journalctl -b 0 --no-pager -o short-precise 2>/dev/null | grep -iE "12:22:3|12:22:4|12:23:0" | grep -iE "NetworkManager|wlan|suspend|sleep|wake" | tail -15

echo
echo "=== wakeup sources enabled"
cat /proc/acpi/wakeup 2>/dev/null | head -5
echo "  wakeup devices: $(grep -l enabled /sys/class/wakeup/*/status 2>/dev/null | wc -l)"
for w in /sys/class/wakeup/wakeup*/; do
    n=$(cat "$w/name" 2>/dev/null)
    [ -n "$n" ] && echo "  $n: $(cat "$w/status" 2>/dev/null) events=$(cat "$w/event_count" 2>/dev/null)"
done | head -12
