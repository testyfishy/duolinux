#!/bin/sh
# Find out exactly why tailscaled dies, and whether it can run without netfilter.
set -u

echo "=== any netfilter table modules on disk?"
find /lib/modules /usr/lib/modules -name "ip_tables.ko*" -o -name "nf_tables.ko*" 2>/dev/null | head -5
echo "=== module tree sanity:"
ls /lib/modules/7.2.0/kernel/net/ 2>/dev/null

echo "=== foreground start, netfilter off (15 s):"
timeout 15 /usr/sbin/tailscaled --state=/var/lib/tailscale/tailscaled.state \
    --socket=/run/tailscale/tailscaled.sock --port=41641 --netfilter-mode=off \
    --verbose=2 >/tmp/ts-fg.log 2>&1
echo "exit=$?"
grep -viE "flushing log|logger closing|logpolicy" /tmp/ts-fg.log | tail -25

echo "=== userspace networking attempt (10 s):"
timeout 10 /usr/sbin/tailscaled --state=/tmp/ts-us.state \
    --socket=/tmp/ts-us.sock --tun=userspace-networking --verbose=1 >/tmp/ts-us.log 2>&1
echo "exit=$?"
grep -viE "flushing log|logger closing|logpolicy" /tmp/ts-us.log | tail -12
