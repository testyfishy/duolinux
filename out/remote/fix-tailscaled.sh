#!/bin/sh
# Why tailscaled exits, and whether it is just a missing iptables/nft.
set -u

echo "=== binaries:"
for b in iptables iptables-legacy iptables-nft ip6tables nft ip; do
    printf '%s: %s\n' "$b" "$(command -v "$b" || echo missing)"
done
echo "=== tun device:"
ls -l /dev/net/tun 2>&1
lsmod 2>/dev/null | grep -E "^tun" || echo "tun not a module (builtin or absent)"
echo "=== tun support:"
ip tuntap 2>&1 | head -3
echo "=== first failure lines:"
journalctl -u tailscaled -n 60 --no-pager 2>&1 | grep -iE "error|fail|fatal|tun|iptables|netlink|permission" | head -15

echo "=== install netfilter tools"
DEBIAN_FRONTEND=noninteractive apt-get install -y iptables nftables 2>&1 | tail -5
for b in iptables nft; do printf '%s: %s\n' "$b" "$(command -v "$b" || echo missing)"; done

systemctl reset-failed tailscaled 2>&1
systemctl restart tailscaled 2>&1
sleep 8
echo "tailscaled: $(systemctl is-active tailscaled)"
tailscale status 2>&1 | head -3
echo "=== log after restart:"
journalctl -u tailscaled --since '-1 min' --no-pager 2>&1 | tail -12
