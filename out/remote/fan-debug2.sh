#!/bin/bash
set -u
H=""
for h in /sys/class/hwmon/hwmon*; do
  [ "$(cat "$h/name" 2>/dev/null)" = "pwmfan" ] && H="$h"
done
echo "=== current"
echo "  pwm1=$(cat "$H/pwm1") enable=$(cat "$H/pwm1_enable") rpm=$(cat "$H/fan1_input")"
for c in /sys/class/thermal/cooling_device*; do
  [ "$(cat "$c/type" 2>/dev/null)" = "pwm-fan" ] && echo "  cooling cur=$(cat "$c/cur_state") max=$(cat "$c/max_state")"
done
echo "=== duo-fan journal"
journalctl -u duo-fan -n 15 --no-pager 2>&1 | tail -10
echo "=== manual write with the daemon stopped"
systemctl stop duo-fan
sleep 1
echo 1 > "$H/pwm1_enable"
echo 0 > "$H/pwm1"
sleep 3
echo "  after write: pwm1=$(cat "$H/pwm1") enable=$(cat "$H/pwm1_enable") rpm=$(cat "$H/fan1_input")"
echo "=== cooling device after write"
for c in /sys/class/thermal/cooling_device*; do
  [ "$(cat "$c/type" 2>/dev/null)" = "pwm-fan" ] && echo "  cooling cur=$(cat "$c/cur_state")"
done
systemctl start duo-fan
