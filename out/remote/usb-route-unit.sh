#!/bin/bash
# Dedicated unit for the USB internet route, ordered after the gadget.
set -u

cat > /usr/local/bin/duo-usb-route <<'EOF'
#!/bin/sh
for i in $(seq 1 20); do
  ip link show usb0 >/dev/null 2>&1 && ip addr show usb0 | grep -q '10.55.0.1' && break
  sleep 1
done
ip route replace default via 10.55.0.2 dev usb0 metric 1000 2>/dev/null || true
exit 0
EOF
chmod 755 /usr/local/bin/duo-usb-route

cat > /etc/systemd/system/duo-usb-route.service <<'EOF'
[Unit]
Description=Route internet over the USB link to the PC
After=duo-usb-gadget.service network.target
Wants=duo-usb-gadget.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/duo-usb-route

[Install]
WantedBy=multi-user.target
EOF
chmod 644 /etc/systemd/system/duo-usb-route.service

systemctl daemon-reload
systemctl enable --now duo-usb-route.service
sleep 2
ip route show default

echo "=== chrony after 20s"
sleep 20
chronyc tracking 2>&1 | grep -E 'Reference ID|System time|Leap|Stratum'
date -u
timedatectl 2>/dev/null | grep -E 'synchronized'
