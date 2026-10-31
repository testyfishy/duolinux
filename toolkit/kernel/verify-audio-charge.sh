#!/bin/sh
set -u
echo "=== a630_sqe.fw: present now? did 7.2.0-nf warn too?"
ls -l /lib/firmware/qcom/a630_sqe.fw 2>/dev/null || echo "  no a630_sqe.fw on disk (expected: writeback only)"
echo "  this boot:  $(journalctl -b 0 --no-pager 2>/dev/null | grep -c a630_sqe)"
echo "  prev boot:  $(journalctl -b -1 --no-pager 2>/dev/null | grep -c a630_sqe)"
echo "  prev kernel: $(journalctl -b -1 -k --no-pager 2>/dev/null | grep -m1 'Linux version' | cut -c1-60)"

echo
echo "=== audio stack"
echo "  pipewire:  $(su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active pipewire' 2>/dev/null)"
echo "  wireplumber: $(su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active wireplumber' 2>/dev/null)"
echo "  cards:"; su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 pactl list short cards' 2>/dev/null | sed 's/^/    /'
echo "  sinks:"; su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 pactl list short sinks' 2>/dev/null | sed 's/^/    /'
echo "  alsa devices: $(ls /dev/snd 2>/dev/null | tr '\n' ' ')"

echo
echo "=== charger / jeita (the 0032 path)"
echo "  bq256xx driver: $(ls /sys/class/power_supply/ | tr '\n' ' ')"
for p in pmi632-charger battery; do
    echo "  --- $p"
    for f in capacity status temp voltage_now current_now input_current_limit constant_charge_current; do
        [ -r "/sys/class/power_supply/$p/$f" ] && echo "    $f: $(cat "/sys/class/power_supply/$p/$f")"
    done
done
echo "  jeita params: $(ls /sys/module/*/parameters 2>/dev/null | grep -c jeita)"

echo
echo "=== dmesg: charger/battery errors this boot"
dmesg | grep -iE "bq256|charger|jeita" | grep -iE "error|fail|warn" | head -6
echo "  (count: $(dmesg | grep -iE "bq256|charger|jeita" | grep -icE "error|fail"))"
