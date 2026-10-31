#!/bin/sh
# Start tailscale auth in the background and print the login URL.
set -u
rm -f /tmp/ts.auth.log
nohup tailscale up --accept-dns=false --reset > /tmp/ts.auth.log 2>&1 &
sleep 6
echo "=== url"
grep -oE 'https://login\.tailscale\.com/[a-z0-9/]+' /tmp/ts.auth.log | head -1
echo "=== state"
tailscale status 2>&1 | head -3
echo "=== service: $(systemctl is-active tailscaled)"
