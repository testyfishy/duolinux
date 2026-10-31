#!/bin/sh
set -u
echo "=== every suspend this boot, with who asked for it"
journalctl -b 0 --no-pager -o short-precise 2>/dev/null | grep -E "duo-lid:|will suspend|PM: suspend entry|PM: suspend exit|Lid closed|Lid opened" | tail -30

echo
echo "=== counts"
echo "  duo-lid 'suspending' lines: $(journalctl -b 0 --no-pager 2>/dev/null | grep -c 'duo-lid.*suspending')"
echo "  logind 'will suspend':      $(journalctl -b 0 --no-pager 2>/dev/null | grep -c 'will suspend')"
echo "  kernel suspend entry:       $(dmesg | grep -c 'suspend entry')"
echo "  suspend_stats success:      $(cat /sys/power/suspend_stats/success)"
echo "  uptime: $(uptime -p)"

echo
echo "=== lid switch current state"
cat /proc/bus/input/devices 2>/dev/null | grep -A5 "gpio-keys-lid" | head -8
evtest --query /dev/input/event3 EV_SW 0 2>/dev/null; echo "  evtest SW_LID=$?"

echo
echo "=== PowerDevil's view (it holds the lid inhibitor)"
journalctl -b 0 --no-pager 2>/dev/null | grep -i "powerdevil" | grep -i lid | tail -5
