#!/bin/bash
# Read the Duo's fan + battery state (runs on the device).
echo "=== fan"
for h in /sys/class/hwmon/hwmon*; do
  [ "$(cat "$h/name" 2>/dev/null)" = "pwmfan" ] || continue
  echo "path        = $h"
  echo "pwm1        = $(cat "$h/pwm1" 2>/dev/null)"
  echo "pwm1_enable = $(cat "$h/pwm1_enable" 2>/dev/null)"
  echo "fan1_input  = $(cat "$h/fan1_input" 2>/dev/null) rpm"
done

echo "=== pwm channels"
ls /sys/class/pwm/ 2>/dev/null

echo "=== battery"
for p in /sys/class/power_supply/*; do
  [ -e "$p" ] || continue
  t=$(cat "$p/type" 2>/dev/null)
  [ "$t" = "Battery" ] || continue
  echo "--- $(basename "$p")"
  for f in status capacity voltage_now current_now power_now charge_now health; do
    [ -e "$p/$f" ] && echo "  $f = $(cat "$p/$f" 2>/dev/null)"
  done
done

echo "=== i3status battery config"
cat /home/duo/.config/i3status/config 2>/dev/null | head -20

echo "=== cooling devices"
for c in /sys/class/thermal/cooling_device*; do
  [ -e "$c" ] || continue
  echo "$(basename "$c") type=$(cat "$c/type" 2>/dev/null) cur=$(cat "$c/cur_state" 2>/dev/null) max=$(cat "$c/max_state" 2>/dev/null)"
done
