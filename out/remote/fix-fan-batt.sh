#!/bin/bash
set -u
install -m 755 /tmp/duo-fan /usr/local/bin/duo-fan
systemctl restart duo-fan
sleep 5

echo "=== fan after the simplified curve"
for h in /sys/class/hwmon/hwmon*; do
  [ "$(cat "$h/name" 2>/dev/null)" = "pwmfan" ] || continue
  echo "  pwm1=$(cat "$h/pwm1") enable=$(cat "$h/pwm1_enable") rpm=$(cat "$h/fan1_input")"
done
echo "  hottest=$(sort -n /sys/class/thermal/thermal_zone*/temp | tail -1)"
systemctl is-active duo-fan

echo
echo "=== can i3status read a battery called 'battery'?"
cat > /tmp/bat-test.conf <<'EOF'
general { interval = 1 }
order += "battery all"
battery all {
    format = "%status %percentage"
    path = "/sys/class/power_supply/battery"
}
EOF
timeout 4 i3status -c /tmp/bat-test.conf 2>&1 | head -4

echo
echo "=== same test without path (does it find BAT0 only?)"
cat > /tmp/bat-test2.conf <<'EOF'
general { interval = 1 }
order += "battery all"
battery all { format = "%status %percentage" }
EOF
timeout 4 i3status -c /tmp/bat-test2.conf 2>&1 | head -4
