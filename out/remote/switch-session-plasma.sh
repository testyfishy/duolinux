#!/bin/bash
set -u
install -m 755 /tmp/duo-session /usr/local/bin/duo-session
sh -n /usr/local/bin/duo-session && echo "duo-session: syntax ok"

mkdir -p /etc/duo
cp /usr/local/bin/duo-session /root/rollback/duo-session.sway 2>/dev/null || true
printf 'plasma\n' > /etc/duo/session
echo "session set to: $(cat /etc/duo/session)"

echo "=== early detect still enabled?"
systemctl is-enabled duo-bottom-detect.service

echo "=== kwin / plasma bits"
for b in kwin_wayland startplasma-wayland plasmashell kded6; do
    printf '%-22s %s\n' "$b" "$(command -v $b 2>/dev/null || find /usr/lib -name "$b" -print -quit 2>/dev/null || echo MISSING)"
done

echo "=== reboot now"
systemctl reboot
