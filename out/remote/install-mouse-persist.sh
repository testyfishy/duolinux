#!/bin/bash
set -u
install -m 755 /tmp/duo-mouse-apply /usr/local/bin/duo-mouse-apply
install -m 755 /tmp/duo-mouse-toggle /usr/local/bin/duo-mouse-toggle
mkdir -p /etc/duo
[ -f /etc/duo/mouse-mode ] || printf 'on\n' > /etc/duo/mouse-mode

cat > /etc/systemd/system/duo-mouse.service <<'EOF'
[Unit]
Description=Apply the saved mouse-mode setting
After=inputplumber.service
Wants=inputplumber.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/duo-mouse-apply
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
chmod 644 /etc/systemd/system/duo-mouse.service

systemctl daemon-reload
systemctl enable duo-mouse.service >/dev/null 2>&1
systemctl start duo-mouse.service
sleep 3

echo "=== mode: $(cat /etc/duo/mouse-mode)  stick: $(cat /home/duo/.config/duo/mouse-stick 2>/dev/null || echo right)"
journalctl -u inputplumber -n 8 --no-pager | grep -i "Loading device profile" | tail -2
systemctl is-active duo-mouse
