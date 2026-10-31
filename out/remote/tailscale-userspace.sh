#!/bin/sh
# Run Tailscale without kernel netfilter or policy routing.
#
# This kernel is built with CONFIG_NF_TABLES off and no IP_MULTIPLE_TABLES, and
# the ip_tables module is not shipped, so tailscaled's normal TUN mode cannot
# install firewall rules or policy routes. Userspace networking avoids both.
set -u

if grep -q "^FLAGS=" /etc/default/tailscaled 2>/dev/null; then
    sed -i 's|^FLAGS=.*|FLAGS="--tun=userspace-networking --socks5-server=127.0.0.1:1055"|' /etc/default/tailscaled
else
    echo 'FLAGS="--tun=userspace-networking --socks5-server=127.0.0.1:1055"' >> /etc/default/tailscaled
fi
grep -E "^FLAGS=" /etc/default/tailscaled

systemctl reset-failed tailscaled 2>&1
systemctl restart tailscaled 2>&1
sleep 8
echo "tailscaled: $(systemctl is-active tailscaled)"
tailscale status 2>&1 | head -3

echo "=== login:"
nohup tailscale up --hostname=retro-duo-lite --accept-dns=false >/tmp/tailscale-up.log 2>&1 &
sleep 12
cat /tmp/tailscale-up.log

echo "=== what inbound forwarding is available:"
tailscale serve --help 2>&1 | grep -iE "tcp|funnel|serve" | head -8
echo "=== addresses:"
tailscale ip -4 2>&1 | head -2
