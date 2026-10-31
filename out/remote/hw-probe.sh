#!/bin/bash
echo "=== hwmon devices (fan control lives here)"
for h in /sys/class/hwmon/hwmon*; do
  [ -e "$h" ] || continue
  echo "--- $h name=$(cat "$h/name" 2>/dev/null)"
  ls "$h" | grep -E 'fan|pwm|temp' | head -10
done

echo "=== power supply (battery/charger)"
for p in /sys/class/power_supply/*; do
  [ -e "$p" ] || continue
  echo "--- $p type=$(cat "$p/type" 2>/dev/null) online=$(cat "$p/online" 2>/dev/null) capacity=$(cat "$p/capacity" 2>/dev/null)"
done
[ -d /sys/class/power_supply ] || echo "no power_supply class at all"

echo "=== relevant modules"
lsmod | grep -iE 'fan|pwm|thermal|batt|charg|smb|qcom_' | head -20

echo "=== thermal zones"
for z in /sys/class/thermal/thermal_zone*; do
  [ -e "$z" ] || continue
  echo "$(basename "$z") $(cat "$z/type" 2>/dev/null) $(cat "$z/temp" 2>/dev/null)"
done

echo "=== any fan/power services in Debian image"
systemctl list-units --all --no-pager 2>/dev/null | grep -iE 'fan|thermal|batt|power' | head -10
