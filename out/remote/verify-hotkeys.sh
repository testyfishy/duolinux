#!/bin/bash
set -u
systemctl restart inputplumber
sleep 6
echo "=== inputplumber"
systemctl is-active inputplumber
journalctl -u inputplumber -n 12 --no-pager 2>&1 | grep -iE 'CompositeDevice|target|mouse|matching' | tail -6

echo "=== devices now"
for f in /sys/class/input/event*/device/name; do
  n=$(cat "$f" 2>/dev/null)
  case "$n" in
    *InputPlumber*|*DualSense*|*Retroid*) echo "  $n";;
  esac
done

echo "=== hotkey watcher"
systemctl is-active duo-padhotkeys
journalctl -u duo-padhotkeys -n 6 --no-pager 2>&1 | tail -4

echo "=== profiles present"
ls -l /etc/inputplumber/profiles/
