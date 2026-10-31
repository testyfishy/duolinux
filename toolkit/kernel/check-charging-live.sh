#!/bin/sh
# Charging check while the cable is plugged in.
set -u
echo "=== now: $(date)"
for p in battery pmi632-charger; do
  for f in status capacity voltage_now current_now input_current_limit temp; do
    [ -r "/sys/class/power_supply/$p/$f" ] && echo "  $p/$f: $(cat "/sys/class/power_supply/$p/$f")"
  done
done
echo "  typec online: $(cat /sys/class/power_supply/tcpm-source-psy-1c40000.spmi:pmic@2:typec@1500/online 2>/dev/null)"
echo "  udc state:    $(cat /sys/class/udc/*/state 2>/dev/null)"
echo
echo "=== IRQ counters (looking for a third transition)"
grep -E "cc-state-change|vbus-change|attach-detach" /proc/interrupts | awk '{print "  "$NF": "$2}'
echo
echo "=== errors in the charger path since boot"
echo "  $(dmesg | grep -iE 'bq256|jeita' | grep -icE 'error|fail|warn|BUG') error lines"
dmesg | grep -iE 'bq256|jeita' | grep -iE 'error|fail|warn' | tail -3
echo
echo "=== battery trend (2 samples, 10s apart)"
for i in 1 2; do
    echo "  $(date +%H:%M:%S): $(cat /sys/class/power_supply/battery/capacity)% $(cat /sys/class/power_supply/battery/status) $(cat /sys/class/power_supply/battery/current_now)uA $(cat /sys/class/power_supply/battery/voltage_now)uV"
    [ "$i" = 1 ] && sleep 10
done
