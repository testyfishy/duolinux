#!/bin/sh
# Drop the tokio-worker experiment (no gain) and measure what the ds5 target costs.
set -u

rm -f /etc/systemd/system/inputplumber.service.d/zz-tokio.conf
systemctl daemon-reload
systemctl restart inputplumber
sleep 20

P=$(pgrep -x inputplumber | head -1)
echo "=== with ds5 target (baseline after removing tokio override)"
ps -o pid,%cpu,args -p "$P" | tail -1
top -H -b -d 15 -n 2 -p "$P" 2>/dev/null | awk '/^top -/{n++} n==2' | sed -n '6,10p'

echo "=== target CLI"
/usr/local/bin/inputplumber device 0 targets --help 2>&1 | head -12

echo "=== removing ds5 target (keyboard + mouse only)"
/usr/local/bin/inputplumber device 0 targets set keyboard mouse 2>&1 | head -5
sleep 25
P=$(pgrep -x inputplumber | head -1)
ps -o pid,%cpu,args -p "$P" | tail -1
top -H -b -d 15 -n 2 -p "$P" 2>/dev/null | awk '/^top -/{n++} n==2' | sed -n '6,10p'
/usr/local/bin/inputplumber device 0 info 2>&1 | grep -iE "target|state" | head -8

echo "=== restoring ds5"
/usr/local/bin/inputplumber device 0 targets set keyboard mouse ds5 2>&1 | head -5
sleep 10
/usr/local/bin/inputplumber device 0 info 2>&1 | grep -iE "target" | head -6
