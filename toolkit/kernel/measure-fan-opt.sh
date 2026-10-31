#!/bin/sh
# Deploy and measure the rebuilt fan daemon.
set -u
install -m 755 /tmp/duo-fan /usr/local/bin/duo-fan
systemctl restart duo-fan
sleep 3

pid=$(systemctl show -p MainPID --value duo-fan)
echo "pid: $pid  active: $(systemctl is-active duo-fan)"
echo "pss: $(awk '/^Pss:/{print $2" kB"}' /proc/$pid/smaps_rollup 2>/dev/null)"

c0=$(systemctl show -p CPUUsageNSec --value duo-fan)
n0=$(journalctl -u duo-fan --no-pager 2>/dev/null | wc -l)
j0=$(journalctl -u duo-fan --no-pager 2>/dev/null | tail -1 | cut -c1-15)

sleep 180

c1=$(systemctl show -p CPUUsageNSec --value duo-fan)
n1=$(journalctl -u duo-fan --no-pager 2>/dev/null | wc -l)
pid=$(systemctl show -p MainPID --value duo-fan)

echo
echo "=== over 180 s"
echo "  cpu: $(( (c1 - c0) / 1000000 )) ms  = $(awk -v d=$((c1 - c0)) 'BEGIN{printf "%.3f%%", d/1e9/180*100}') of one core"
echo "  journal lines: $((n1 - n0))  (old daemon: 29.8/min = ~89 in 3 min)"
echo "  pss now: $(awk '/^Pss:/{print $2" kB"}' /proc/$pid/smaps_rollup 2>/dev/null)"
echo "  switches: vol=$(awk '/voluntary_ctxt_switches/{print $2}' /proc/$pid/status) nonvol=$(awk '/nonvoluntary_ctxt_switches/{print $2}' /proc/$pid/status)"
echo
echo "=== last lines"
journalctl -u duo-fan --no-pager -n 4 | sed 's/^/  /'
echo
echo "=== fan state"
echo "  pwm1=$(cat /sys/class/hwmon/*/pwm1 2>/dev/null | head -1) avg/hottest=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)"
