#!/bin/sh
# Did the plug/unplug events reach the charger driver cleanly?
set -u
echo "=== current power state"
for p in battery pmi632-charger; do
    for f in status capacity voltage_now current_now temp; do
        [ -r "/sys/class/power_supply/$p/$f" ] && echo "  $p/$f: $(cat /sys/class/power_supply/$p/$f)"
    done
done

echo
echo "=== typec source"
for f in online status type; do
    v=$(cat "/sys/class/power_supply/tcpm-source-psy-1c40000.spmi:pmic@2:typec@1500/$f" 2>/dev/null)
    [ -n "$v" ] && echo "  $f: $v"
done

echo
echo "=== charger events in this boot"
journalctl -b 0 --no-pager 2>/dev/null | grep -iE "bq256|charger|typec|usb.*(attach|detach)|power_supply" | tail -12

echo
echo "=== errors during/after the hot-plug"
dmesg | grep -iE "bq256|jeita|charger|typec" | grep -iE "error|fail|warn|BUG|oops" | head -8
echo "  count: $(dmesg | grep -iE "bq256|jeita" | grep -icE "error|fail|warn")"

echo
echo "=== did anything crash or get oopsed?"
echo "  oops/panic this boot: $(journalctl -b 0 -k --no-pager 2>/dev/null | grep -icE 'oops|panic|BUG:|general protection')"
echo "  failed units: $(systemctl list-units --state=failed --no-legend | wc -l)"
echo "  uptime: $(uptime -p)"
echo "  jeita symbols loaded: $(grep -c bq256xx_jeita /proc/kallsyms)"
