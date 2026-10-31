#!/bin/sh
# Did PowerDevil (not duo-lid) suspend on the lid, and did it resume?
set -u
echo "=== suspend stats"
echo "  success: $(cat /sys/power/suspend_stats/success)"

echo
echo "=== last lid/suspend events"
journalctl -b 0 --no-pager -o short-precise 2>/dev/null \
  | grep -E "Lid closed|Lid opened|will suspend|PM: suspend entry|PM: suspend exit|duo-lid" \
  | tail -12

echo
echo "=== who asked for it"
echo "  duo-lid lines this boot: $(journalctl -b 0 --no-pager 2>/dev/null | grep -c 'duo-lid')"
echo "  duo-lid service: $(systemctl is-active duo-lid 2>/dev/null) / $(systemctl is-enabled duo-lid 2>/dev/null)"
echo "  powerdevil log (lid mentions):"
journalctl -b 0 --no-pager 2>/dev/null | grep -i powerdevil | grep -iE "lid|suspend|sleep" | tail -5

echo
echo "=== panels after resume"
for s in /sys/class/drm/card0-*/status; do echo "  $(basename "$(dirname "$s")"): $(cat "$s")"; done
