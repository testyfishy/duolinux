#!/bin/bash
set -u
echo "=== add default route over USB (high metric so Wi-Fi wins later)"
ip route replace default via 10.55.0.2 dev usb0 metric 1000
ip route show default

echo "=== DNS"
if systemctl is-active systemd-resolved >/dev/null 2>&1; then
  resolvectl dns usb0 1.1.1.1 9.9.9.9 2>&1 | head -2
  resolvectl domain usb0 '~.' 2>&1 | head -2
else
  [ -f /etc/resolv.conf ] && cp -n /etc/resolv.conf /etc/resolv.conf.bak
  printf 'nameserver 1.1.1.1\nnameserver 9.9.9.9\n' > /etc/resolv.conf
fi
cat /etc/resolv.conf | head -5

echo "=== connectivity"
ping -c 2 -W 2 1.1.1.1 2>&1 | tail -2
getent hosts deb.debian.org 2>&1 | head -2
timeout 20 curl -sI https://deb.debian.org/debian/ 2>&1 | head -3
