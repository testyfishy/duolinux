#!/bin/bash
# Set the clock from an HTTPS Date header: NTP/UDP is blocked through the USB NAT,
# but HTTPS works (apt depends on it).
set -u

cat > /usr/local/bin/duo-clock <<'EOF'
#!/bin/sh
# Wait for the USB route, then take the time from an HTTPS response.
for i in $(seq 1 30); do
  d=$(curl -4 -sI --max-time 6 https://deb.debian.org/ 2>/dev/null | tr -d '\r' \
      | awk -F': ' 'tolower($1)=="date"{print $2; exit}')
  if [ -n "$d" ] && date -u -s "$d" >/dev/null 2>&1; then
    exit 0
  fi
  sleep 3
done
exit 0
EOF
chmod 755 /usr/local/bin/duo-clock

cat > /etc/systemd/system/duo-clock.service <<'EOF'
[Unit]
Description=Set the clock from an HTTPS Date header
After=network.target duo-usb-route.service
Wants=duo-usb-route.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/duo-clock

[Install]
WantedBy=multi-user.target
EOF
chmod 644 /etc/systemd/system/duo-clock.service

systemctl daemon-reload
systemctl enable duo-clock.service >/dev/null 2>&1
systemctl start duo-clock.service
sleep 2
echo "=== clock now"
date -u
echo "=== service state"
systemctl is-active duo-clock
