#!/bin/bash
set -u
install -m 755 /tmp/duo-keylog /usr/local/bin/duo-keylog
pkill -f duo-keylog 2>/dev/null || true
sleep 1
: > /var/log/duo-keylog.txt
setsid /usr/local/bin/duo-keylog >/dev/null 2>&1 < /dev/null &
sleep 2
echo "logger pid(s): $(pgrep -f duo-keylog | tr '\n' ' ')"
head -3 /var/log/duo-keylog.txt
