#!/bin/bash
# Install ROCKNIX's InputPlumber and hand the gamepad over to it.
set -u

echo "=== extracting payload"
mkdir -p /opt/duo-plumber
tar -xzf /tmp/plumber.tgz -C / || { echo "extract failed"; exit 1; }
chmod 755 /usr/bin/inputplumber
chmod 755 /usr/lib/inputplumber/setfacl-shim/setfacl 2>/dev/null

echo "=== stop our interim remapper (it grabs the pad)"
systemctl stop duo-inputd 2>/dev/null
systemctl mask duo-inputd 2>/dev/null

echo "=== udev + hwdb"
systemd-hwdb update 2>/dev/null || true
udevadm control --reload-rules 2>/dev/null || true
udevadm trigger 2>/dev/null || true

echo "=== enable inputplumber"
systemctl daemon-reload
systemctl enable inputplumber.service 2>&1 | tail -2
systemctl start inputplumber.service 2>&1 | tail -2
sleep 6

echo "=== status"
systemctl is-active inputplumber
journalctl -u inputplumber -n 40 --no-pager 2>&1 | tail -30

echo "=== virtual devices it created"
grep -H . /sys/class/input/event*/device/name 2>/dev/null | sed 's|/sys/class/input/||' | tail -15

echo "=== duo-inputd state"
systemctl is-enabled duo-inputd 2>&1
