#!/bin/sh
# What actually happened on lid close/open, and who owns the lid decision.
set -u
echo "=== events since boot, lid-related"
journalctl -b 0 --no-pager 2>/dev/null | grep -iE "lid|suspend|resume|dpms|screen.*(off|on)" | grep -viE "maliit|slid|invalid" | tail -25

echo
echo "=== did logind suspend?"
echo "  'will suspend' count: $(journalctl -b 0 --no-pager 2>/dev/null | grep -ic 'will suspend')"
echo "  'System resumed' count: $(journalctl -b 0 --no-pager 2>/dev/null | grep -ic 'resume')"
echo "  uptime: $(uptime -p)"
echo "  suspend entries in /sys/power: $(cat /sys/power/state)"

echo
echo "=== who inhibits lid handling?"
systemd-inhibit --list 2>/dev/null | sed -n '1,12p'

echo
echo "=== duo-lid service"
systemctl status duo-lid --no-pager -l 2>/dev/null | tail -12
echo "--- unit:"
cat /etc/systemd/system/duo-lid.service

echo
echo "=== PowerDevil lid config"
su - duo -c 'cat ~/.config/powerdevilrc 2>/dev/null' | sed -n '1,40p'

echo
echo "=== lid switch input state (open now?)"
for d in /sys/class/input/input*/; do
    n=$(cat "$d/name" 2>/dev/null)
    case "$n" in *id*|*Lid*|*GPI*|*gpio*) echo "  $n: $(cat "$d/capabilities/sw" 2>/dev/null)";; esac
done
evtest --query /dev/input/by-path/* 2>/dev/null | head -3
