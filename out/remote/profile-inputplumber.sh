#!/bin/sh
# Locate the 1 kHz polling loop inside inputplumber.
set -u

echo "=== source tree on device:"
ls -d /usr/local/src/* 2>/dev/null | head -5
find / -maxdepth 4 -name "inputplumber" -type d 2>/dev/null | head -5

echo "=== which fd is read and what errno:"
timeout 4 strace -f -p 462 -e trace=read,openat -o /tmp/ip-reads.txt 2>/dev/null
grep -c "read(" /tmp/ip-reads.txt 2>/dev/null
grep "read(" /tmp/ip-reads.txt 2>/dev/null | head -6
grep -oE "EAGAIN|ENODEV|ENOENT" /tmp/ip-reads.txt 2>/dev/null | sort | uniq -c

echo "=== open fds of interest:"
ls -l /proc/462/fd 2>/dev/null | grep -E "input|hidraw|uinput|dri|event" | head -10

echo "=== gamepad profile:"
sed -n '1,60p' /etc/inputplumber/profiles/gamepad.yaml 2>/dev/null

echo "=== pad node service:"
systemctl status duo-pad-node --no-pager 2>&1 | head -8
cat /usr/lib/systemd/system/duo-pad-node.service 2>/dev/null | head -15
