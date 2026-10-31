#!/bin/bash
set -u
S=/mnt/rnx/SYSTEM

echo "=== current fan state"
for h in /sys/class/hwmon/hwmon*; do
  [ "$(cat "$h/name" 2>/dev/null)" = "pwmfan" ] || continue
  echo "pwm1        = $(cat "$h/pwm1" 2>/dev/null)"
  echo "pwm1_enable = $(cat "$h/pwm1_enable" 2>/dev/null)"
  echo "fan1_input  = $(cat "$h/fan1_input" 2>/dev/null)"
done

echo
echo "=== ROCKNIX fan-related files"
unsquashfs -ll "$S" 2>/dev/null | awk '{print $NF}' | grep -iE 'fan' | grep -viE '\.(png|svg|mo|pyc)' | head -25

echo
echo "=== ROCKNIX battery/power files"
unsquashfs -ll "$S" 2>/dev/null | awk '{print $NF}' | grep -iE 'battery|power-supply|fuel' | grep -viE '\.(png|svg|mo|pyc)' | head -20
