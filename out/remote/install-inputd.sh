#!/bin/bash
# Install the corrected input mapper and restart it.
set -u
install -m 755 /tmp/duo-inputd /usr/local/bin/duo-inputd
python3 -c 'import ast,sys; ast.parse(open("/usr/local/bin/duo-inputd").read())' && echo "python syntax OK"
mkdir -p /var/log
: > /var/log/duo-input.log
systemctl restart duo-inputd
sleep 2
systemctl is-active duo-inputd
tail -5 /var/log/duo-input.log 2>/dev/null
echo "=== devices now"
ls -l /dev/input/by-path 2>/dev/null | head
