#!/bin/sh
# Restart duo-backkey properly (user unit) and try to stop InputPlumber from
# polling the haptics device, which produces no input events.
set -u

echo "=== duo-backkey user unit"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user restart duo-backkey' 2>&1
sleep 3
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active duo-backkey' 2>&1

echo "=== inputplumber sources interface"
/usr/local/bin/inputplumber sources --help 2>&1 | head -20
echo "--- current sources:"
/usr/local/bin/inputplumber sources list 2>&1 | head -20

echo "=== config/udev options for excluding a device"
grep -rls "exclude\|ignore\|denylist\|blocklist" /usr/share/doc/inputplumber /usr/share/inputplumber 2>/dev/null | head -5
/usr/local/bin/inputplumber --help 2>&1 | sed -n '1,40p'

echo "=== current CPU of the two daemons (20 s)"
top -b -d 20 -n 2 2>/dev/null | awk '/^top -/{n++} n==2' | sed -n '7,14p'
