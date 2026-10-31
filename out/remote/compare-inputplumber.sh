#!/bin/sh
# Compare stock inputplumber against the patched build at idle.
set -u

systemctl stop inputplumber 2>&1
sleep 3

echo "=== stock 0.82.0, 25 s"
nohup /usr/bin/inputplumber >/tmp/ip-stock.log 2>&1 &
sleep 25
P=$(pgrep -f "^/usr/bin/inputplumber" | head -1)
if [ -n "$P" ]; then
    top -H -b -d 20 -n 2 -p "$P" 2>/dev/null | awk '/^top -/{n++} n==2' | sed -n '6,12p'
    echo "--- syscalls:"
    timeout 5 strace -c -f -p "$P" 2>&1 | sed -n '1,10p'
    kill "$P" 2>/dev/null
else
    echo "stock binary did not start:"
    tail -5 /tmp/ip-stock.log
fi

sleep 3
systemctl start inputplumber 2>&1
sleep 5
echo "=== restored: $(systemctl is-active inputplumber) $(readlink -f /proc/$(pgrep -x inputplumber | head -1)/exe)"
