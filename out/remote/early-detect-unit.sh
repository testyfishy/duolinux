#!/bin/bash
set -u

cat > /etc/systemd/system/duo-bottom-detect.service <<'EOF'
[Unit]
Description=Force the Duo Lite bottom panel (DP-1) to be detected
DefaultDependencies=no
Before=graphical.target display-manager.service
After=systemd-udevd.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/duo-bottom-detect
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
EOF
chmod 644 /etc/systemd/system/duo-bottom-detect.service

systemctl daemon-reload
systemctl enable duo-bottom-detect.service 2>&1 | tail -1
systemctl start duo-bottom-detect.service
sleep 1
echo "DP-1 status: $(cat /sys/class/drm/card0-DP-1/status)"
echo "=== is the plasma install done?"
if pgrep -f apt-get >/dev/null; then
    echo "  still running"
    tail -3 /var/log/plasma-install.log
else
    tail -8 /var/log/plasma-install.log
fi
