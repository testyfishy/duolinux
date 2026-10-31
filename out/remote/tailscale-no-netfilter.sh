#!/bin/sh
# Tailscale needs netfilter; this kernel may not provide it. Confirm, then run
# the daemon with netfilter management off (client-only, rules managed elsewhere).
set -u

echo "=== iptables usability:"
iptables --version 2>&1
iptables -L -n 2>&1 | head -3
echo "--- nft backend:"
iptables-nft -L -n 2>&1 | head -3
echo "--- nftables:"
nft list ruleset 2>&1 | head -3
echo "--- kernel tables:"
cat /proc/net/ip_tables_names 2>&1
echo "--- netfilter symbols:"
ls /sys/module | grep -E "nf_tables|ip_tables|iptable" | head -5 || echo none
zcat /proc/config.gz 2>/dev/null | grep -E "^CONFIG_(NF_TABLES|IP_NF_IPTABLES|IP_MULTIPLE_TABLES)=" || echo "no /proc/config.gz"

echo "=== current unit flags:"
cat /etc/default/tailscaled 2>/dev/null | grep -E "^(FLAGS|PORT)=" || true

echo "=== switch to netfilter-mode=off"
if grep -q "^FLAGS=" /etc/default/tailscaled 2>/dev/null; then
    sed -i 's|^FLAGS=.*|FLAGS="--netfilter-mode=off"|' /etc/default/tailscaled
else
    echo 'FLAGS="--netfilter-mode=off"' >> /etc/default/tailscaled
fi
grep -E "^FLAGS=" /etc/default/tailscaled

systemctl reset-failed tailscaled 2>&1
systemctl restart tailscaled 2>&1
sleep 8
echo "tailscaled: $(systemctl is-active tailscaled)"
journalctl -u tailscaled --since '-1 min' --no-pager 2>&1 | tail -6

if [ "$(systemctl is-active tailscaled)" = "active" ]; then
    echo "=== login:"
    nohup tailscale up --hostname=retro-duo-lite --accept-dns=false >/tmp/tailscale-up.log 2>&1 &
    sleep 10
    cat /tmp/tailscale-up.log
fi
