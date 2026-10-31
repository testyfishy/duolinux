#!/bin/sh
set -u
echo "=== status"
tailscale status 2>&1 | head -8 | sed 's/^/  /'

echo
echo "=== address"
echo "  ipv4: $(tailscale ip -4 2>/dev/null | head -1)"
echo "  ipv6: $(tailscale ip -6 2>/dev/null | head -1)"
echo "  state file: $(stat -c %s /var/lib/tailscale/tailscaled.state 2>/dev/null) bytes"

echo
echo "=== backend + health"
tailscale status --json 2>/dev/null | grep -oE '"BackendState":"[^"]*"|"Online":(true|false)' | head -3 | sed 's/^/  /'
tailscale debug prefs 2>/dev/null | grep -E 'RouteAll|ExitNode|CorpDNS' | sed 's/^/  /'

echo
echo "=== path to the HTPC (direct or relayed?)"
tailscale ping -c 3 100.64.0.10 2>&1 | head -6 | sed 's/^/  /'

echo
echo "=== interface"
ip -brief addr show tailscale0 2>/dev/null | sed 's/^/  /'
echo "  routes: $(ip route show table all 2>/dev/null | grep -c tailscale)"
