#!/bin/bash
# Fix the missing Plasma pieces, install instrumented daemon, then reboot so the
# session starts through startplasma-wayland with the correct environment.
set -u
export DEBIAN_FRONTEND=noninteractive

echo "=== plasma-pa (tray audio applet QML module)"
apt-get -o Acquire::ForceIPv4=true install -y --no-install-recommends \
    plasma-pa 2>&1 | tail -3

echo "=== daemon with wheel timing log"
install -m 755 /tmp/bk13.py /usr/local/bin/duo-backkey
python3 -m py_compile /usr/local/bin/duo-backkey && echo "daemon ok"

echo "=== session env sanity"
grep -n "XDG_MENU_PREFIX\|QML_XHR" /usr/local/bin/duo-session || true

echo "=== reboot"
sync
systemctl reboot
