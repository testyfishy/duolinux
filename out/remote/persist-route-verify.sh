#!/bin/bash
# Persist the USB internet route and re-verify the whole boot.
set -u

echo "=== persist default route in the gadget script"
if ! grep -q '10.55.0.2' /usr/local/bin/duo-usb-gadget; then
  cat >> /usr/local/bin/duo-usb-gadget <<'EOF'
# Route out through the PC so time sync and apt work with no Wi-Fi.
ip route replace default via 10.55.0.2 dev usb0 metric 1000 2>/dev/null || true
EOF
  chmod 755 /usr/local/bin/duo-usb-gadget
  echo "appended"
else
  echo "already present"
fi

echo "=== apply now"
ip route replace default via 10.55.0.2 dev usb0 metric 1000
ip route show default

echo "=== resync clock"
systemctl restart chrony 2>/dev/null || true
sleep 6
date -u
timedatectl 2>/dev/null | grep -E 'synchronized|NTP service' || true

echo "=== verification"
cat /proc/sys/kernel/random/boot_id
for s in ssh duo-modem qrtr-ns pd-mapper rmtfs tqftpserv NetworkManager; do
  printf '%-14s %s\n' "$s" "$(systemctl is-active "$s" 2>&1)"
done
ip -br addr show wlan0 2>/dev/null
nmcli -t -f SSID,SIGNAL dev wifi list 2>/dev/null | head -5
pgrep -a sway | head -2
pgrep -a swaybar | head -2
pgrep -a i3status | head -2
tail -4 /home/duo/.local/state/duo/session.log 2>/dev/null
for b in fuzzel foot pcmanfm firefox-esr syncthing wvkbd-mobintl; do
  printf '%-14s %s\n' "$b" "$(command -v "$b" 2>/dev/null || echo MISSING)"
done
