#!/bin/bash
# Install the fan curve and fix the battery readout.
set -u

install -m 755 /tmp/duo-fan /usr/local/bin/duo-fan
python3 -m py_compile /usr/local/bin/duo-fan && echo "fan daemon compiles"

cat > /etc/systemd/system/duo-fan.service <<'EOF'
[Unit]
Description=Duo Lite fan curve
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/duo-fan
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now duo-fan.service 2>&1 | tail -1
sleep 4
systemctl is-active duo-fan

echo "=== fan now"
for h in /sys/class/hwmon/hwmon*; do
  [ "$(cat "$h/name" 2>/dev/null)" = "pwmfan" ] || continue
  echo "  pwm1=$(cat "$h/pwm1") enable=$(cat "$h/pwm1_enable") rpm=$(cat "$h/fan1_input")"
done
echo "  hottest=$(sort -n /sys/class/thermal/thermal_zone*/temp | tail -1)"

echo "=== battery in the bar: does i3status support a path?"
i3status --version 2>&1 | head -2
man i3status 2>/dev/null | col -b 2>/dev/null | grep -A3 -i 'path' | head -12

echo "=== battery facts for the bar"
cat /sys/class/power_supply/battery/{capacity,status} 2>/dev/null
