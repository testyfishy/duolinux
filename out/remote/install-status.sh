#!/bin/bash
set -u
install -m 755 /tmp/duo-status /usr/local/bin/duo-status
python3 -m py_compile /usr/local/bin/duo-status && echo "status generator compiles"

echo "=== sample output"
timeout 4 su - duo -c 'python3 /usr/local/bin/duo-status' 2>&1 | head -4

echo "=== switch swaybar to it"
sed -i 's|status_command i3status|status_command /usr/local/bin/duo-status|' /etc/sway/config
grep -n status_command /etc/sway/config

echo "=== restart the session so the bar picks it up"
pkill -x sway 2>/dev/null || true
sleep 10
pgrep -a sway | head -2
pgrep -a swaybar | head -2

echo "=== fan + battery summary"
for h in /sys/class/hwmon/hwmon*; do
  [ "$(cat "$h/name" 2>/dev/null)" = "pwmfan" ] || continue
  echo "  fan pwm1=$(cat "$h/pwm1") rpm=$(cat "$h/fan1_input")"
done
echo "  battery $(cat /sys/class/power_supply/battery/capacity)% $(cat /sys/class/power_supply/battery/status)"
