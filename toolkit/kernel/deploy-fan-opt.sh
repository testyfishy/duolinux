#!/bin/sh
# Deploy the optimised fan daemon and measure the difference.
set -u
echo "=== baseline (old daemon)"
echo "  journal lines from duo-fan in the last hour: $(journalctl -u duo-fan --since '-1 hour' --no-pager 2>/dev/null | wc -l)"
echo "  lines per minute (last 10 min): $(journalctl -u duo-fan --since '-10 min' --no-pager 2>/dev/null | wc -l | awk '{printf "%.1f", $1/10}')"
pid=$(pgrep -x duo-fan | head -1); [ -z "$pid" ] && pid=$(pgrep -f 'duo-fan' | head -1)
if [ -n "$pid" ]; then
    t=$(awk '{print $14+$15}' /proc/$pid/stat)
    echo "  pid $pid cpu ticks so far: $t"
fi

echo
echo "=== installing"
install -m 755 /tmp/duo-fan /usr/local/bin/duo-fan
systemctl restart duo-fan
sleep 5
echo "  active: $(systemctl is-active duo-fan)"
echo "  rss: $(awk '/VmRSS/{print $2}' /proc/$(pgrep -x duo-fan | head -1)/status 2>/dev/null) kB"

echo
echo "=== first 60 s after restart"
n0=$(journalctl -u duo-fan --no-pager 2>/dev/null | wc -l)
sleep 60
n1=$(journalctl -u duo-fan --no-pager 2>/dev/null | wc -l)
echo "  new journal lines in 60 s: $((n1 - n0))"
journalctl -u duo-fan --no-pager -n 5 2>/dev/null | sed 's/^/    /'

echo
echo "=== cpu over 20 s now"
python3 /tmp/cpuprof.py 20 2>/dev/null | sed -n '/per process/,$p' | head -8
