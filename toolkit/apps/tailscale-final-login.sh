#!/bin/sh
# One final, clean login attempt. No further retries after this.
set -u
echo "=== stopping any pending attempts"
pkill -f "tailscale up" 2>/dev/null
sleep 2
tailscale logout 2>/dev/null || true
sleep 2
echo "  state size now: $(stat -c %s /var/lib/tailscale/tailscaled.state 2>/dev/null)"

echo
echo "=== single login attempt"
rm -f /tmp/tsfinal.log
setsid nohup tailscale up --accept-dns=false >/tmp/tsfinal.log 2>&1 < /dev/null &
sleep 10

URL=$(grep -oE 'https://login\.tailscale\.com/[a-z0-9/]+' /tmp/tsfinal.log | head -1)
echo "  url: ${URL:-none}"
echo "  node key from daemon log:"
journalctl -u tailscaled --since '-2 min' --no-pager 2>/dev/null | grep -oE 'node=\[[A-Za-z0-9]+\]' | tail -1 | sed 's/^/    /'
echo
echo "=== status"
tailscale status 2>&1 | head -3 | sed 's/^/  /'
echo
echo "=== this is the only pending attempt; no more will be started."
