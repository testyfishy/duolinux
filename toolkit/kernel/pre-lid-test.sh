#!/bin/sh
# Charger state + lid-suspend baseline before the lid test.
set -u
echo "=== charging right now"
for f in status capacity voltage_now current_now; do
    echo "  battery/$f: $(cat "/sys/class/power_supply/battery/$f" 2>/dev/null)"
done
echo "  typec online: $(cat /sys/class/power_supply/tcpm-source-psy-*:*:typec@1500/online 2>/dev/null)"
echo "  jeita errors: $(dmesg | grep -iE 'bq256|jeita' | grep -icE 'error|fail|warn')"

echo
echo "=== lid switch"
echo "  SW_LID state: $(cat /proc/acpi/button/lid/*/state 2>/dev/null || echo 'n/a (devicetree)')"
evtest --query /dev/input/event* EV_SW 0 >/dev/null 2>&1 && echo "  (evtest available)"
echo "  lid input devices: $(grep -l -i lid /sys/class/input/*/name 2>/dev/null | wc -l)"

echo
echo "=== logind lid policy"
grep -vE '^\s*#|^\s*$' /etc/systemd/logind.conf /etc/systemd/logind.conf.d/*.conf 2>/dev/null
echo "  runtime: HandleLidSwitch=$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch 2>/dev/null | awk '{print $2}')"

echo
echo "=== our lid handler units"
for u in duo-lid.service duo-lidswitch.service; do
    echo "  $u: $(systemctl is-active "$u" 2>/dev/null)/$(systemctl is-enabled "$u" 2>/dev/null)"
done
ls /etc/systemd/system/duo-lid* /usr/local/lib/duo-lid* /usr/local/bin/duo-lid 2>/dev/null

echo
echo "=== suspends so far this boot"
journalctl -b 0 --no-pager 2>/dev/null | grep -iE "will suspend|Lid|Suspending|resume" | tail -10
echo "  count: $(journalctl -b 0 --no-pager 2>/dev/null | grep -ic 'will suspend')"

echo
echo "=== powerdevil lid setting"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 kreadconfig6 --file powerdevilrc --group SuspendAndShutdown --key LidAction' 2>/dev/null | sed 's/^/  LidAction: /'
