#!/bin/bash
# Clock that can bootstrap without a valid certificate.
set -u

cat > /usr/local/bin/duo-clock <<'EOF'
#!/bin/sh
# 1. Start from the last time we knew (survives reboot without an RTC).
SAVE=/var/lib/duo/lastclock
mkdir -p /var/lib/duo 2>/dev/null
if [ -s "$SAVE" ]; then
  date -u -s "@$(cat "$SAVE")" >/dev/null 2>&1 || true
fi

# 2. Refine from a plain-HTTP Date header (no TLS, so no certificate check).
for i in $(seq 1 20); do
  d=$(curl -4 -sI --max-time 6 http://deb.debian.org/debian/ 2>/dev/null \
      | tr -d '\r' | awk -F': ' 'tolower($1)=="date"{print $2; exit}')
  if [ -n "$d" ] && date -u -s "$d" >/dev/null 2>&1; then
    date -u +%s > "$SAVE"
    exit 0
  fi
  sleep 3
done
exit 0
EOF
chmod 755 /usr/local/bin/duo-clock

# Keep lastclock fresh so a reboot never lands far in the past.
cat > /etc/systemd/system/duo-clock-save.service <<'EOF'
[Unit]
Description=Refresh the saved last-known time

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'mkdir -p /var/lib/duo && date -u +%s > /var/lib/duo/lastclock'
EOF

cat > /etc/systemd/system/duo-clock-save.timer <<'EOF'
[Unit]
Description=Periodically refresh the saved last-known time

[Timer]
OnBootSec=2min
OnUnitActiveSec=15min

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now duo-clock-save.timer >/dev/null 2>&1

echo "=== run the clock unit now"
systemctl restart duo-clock.service
sleep 3
date -u
echo "=== lastclock"
cat /var/lib/duo/lastclock 2>/dev/null
echo
echo "=== service"
systemctl is-active duo-clock duo-clock-save.timer
