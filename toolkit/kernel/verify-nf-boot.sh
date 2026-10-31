#!/bin/sh
set -u
echo "kernel: $(uname -r)"
echo "root: $(findmnt -no SOURCE /)"
modprobe nf_tables nft_nat nft_masq nft_compat xt_MASQUERADE 2>&1
echo "nft list: $(nft list ruleset >/dev/null 2>&1 && echo ok || echo FAIL)"
if nft add table inet t 2>/dev/null &&
   nft add chain inet t c '{ type nat hook postrouting priority 100; }' 2>/dev/null &&
   nft add rule inet t c masquerade 2>/dev/null; then
    echo "nft nat: ok"; nft delete table inet t
else
    echo "nft nat: FAIL"
fi
echo "iptables: $(iptables -L -n >/dev/null 2>&1 && echo ok || echo FAIL)"
if ip rule add fwmark 0x80000 table 52 prio 5270 2>/dev/null; then
    echo "ip rule: ok"; ip rule del prio 5270
else
    echo "ip rule: FAIL"
fi
echo "panels: $(su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 kscreen-doctor -o' 2>/dev/null | grep -c '^Output')"
echo "wifi: $(nmcli -t -f STATE g 2>/dev/null)"
echo "remoteproc: $(cat /sys/class/remoteproc/*/state 2>/dev/null | tr '\n' ' ')"
echo "shell: $(su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active plasma-plasmashell')"
echo "modules 7.2.0-nf: $(find /lib/modules/7.2.0-nf -name '*.ko' | wc -l)"
echo "config NF_TABLES: $(zcat /proc/config.gz 2>/dev/null | grep -c '^CONFIG_NF_TABLES=')"
