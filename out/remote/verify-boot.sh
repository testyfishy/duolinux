#!/bin/bash
# Post-boot verification: access, Wi-Fi, session, UI bits.
set -u
echo "=== boot id / uptime"
cat /proc/sys/kernel/random/boot_id; uptime -s

echo "=== access"
systemctl is-active ssh; ss -ltn | grep -E ':22 |:2222' || true

echo "=== wifi stack"
for s in duo-modem qrtr-ns pd-mapper rmtfs tqftpserv NetworkManager; do
  printf '%-14s %s\n' "$s" "$(systemctl is-active "$s" 2>&1)"
done
ip -br addr show wlan0 2>/dev/null
nmcli -t -f SSID,SIGNAL dev wifi list 2>/dev/null | head -5

echo "=== session"
pgrep -a sway | head -2
pgrep -a swaybar | head -2
pgrep -a i3status | head -2
tail -6 /home/duo/.local/state/duo/session.log 2>/dev/null

echo "=== who writes /run/duo?"
grep -rl '/run/duo' /usr/local/bin /etc/systemd/system 2>/dev/null | head -5

echo "=== installed ui apps"
for b in fuzzel foot pcmanfm firefox-esr syncthing wvkbd-mobintl; do
  printf '%-14s %s\n' "$b" "$(command -v "$b" 2>/dev/null || echo MISSING)"
done
