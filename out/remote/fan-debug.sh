#!/bin/bash
set -u
H=""
for h in /sys/class/hwmon/hwmon*; do
  [ "$(cat "$h/name" 2>/dev/null)" = "pwmfan" ] && H="$h"
done
echo "fan hwmon: $H"
echo "hottest: $(sort -n /sys/class/thermal/thermal_zone*/temp | tail -1)"

echo "=== stop our daemon so nothing fights us"
systemctl stop duo-fan
sleep 1

echo "=== write tests"
for v in 0 51 102 255 0; do
  echo "$v" > "$H/pwm1" 2>/dev/null
  sleep 1
  echo "  wrote $v -> pwm1=$(cat "$H/pwm1") enable=$(cat "$H/pwm1_enable") rpm=$(cat "$H/fan1_input")"
done

echo "=== does the thermal framework own it?"
for c in /sys/class/thermal/cooling_device*; do
  t=$(cat "$c/type" 2>/dev/null)
  [ "$t" = "pwm-fan" ] && echo "  cooling device $(basename "$c") cur=$(cat "$c/cur_state") max=$(cat "$c/max_state")"
done
echo "=== thermal governors/trips referencing the fan"
grep -l "pwm-fan" /sys/class/thermal/thermal_zone*/cdev*_type 2>/dev/null | head -5
