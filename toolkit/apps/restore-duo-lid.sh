#!/bin/sh
set -u
echo "=== all powerdevil config files"
find /home/duo/.config -maxdepth 3 -name "*powerdevil*" -o -maxdepth 3 -name "powermanagement*" 2>/dev/null | sed 's/^/  /'
ls -l /home/duo/.config/powerdevilrc 2>/dev/null

echo
echo "=== does our key survive in each?"
for f in $(find /home/duo/.config -name "*powerdevil*" -type f 2>/dev/null); do
    echo "  $f: $(grep -c inhibitLidActionWhenExternalMonitorPresent "$f" 2>/dev/null) inhibit keys"
done

echo
echo "=== KDE version of powerdevil"
dpkg -l powerdevil 2>/dev/null | awk '/^ii/{print "  "$3}'

echo
echo "=== restore the working daemon until this is understood"
systemctl enable --now duo-lid 2>&1 | tail -2
sleep 2
echo "  duo-lid: $(systemctl is-active duo-lid) / $(systemctl is-enabled duo-lid)"
