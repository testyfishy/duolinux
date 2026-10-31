#!/bin/bash
set -u
echo "=== resolver state"
systemctl is-active systemd-resolved 2>&1
ls -l /etc/resolv.conf
head -5 /etc/resolv.conf

echo "=== set DNS explicitly"
if systemctl is-active systemd-resolved >/dev/null 2>&1; then
  resolvectl dns usb0 1.1.1.1 9.9.9.9 2>&1 | head -2
  resolvectl domain usb0 '~.' 2>&1 | head -2
  resolvectl flush-caches 2>/dev/null
else
  cp -n /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null || true
  printf 'nameserver 1.1.1.1\nnameserver 9.9.9.9\n' > /etc/resolv.conf
fi

echo "=== test"
getent hosts deb.debian.org | head -2
timeout 15 curl -4 -sI https://deb.debian.org/debian/ 2>&1 | head -2
