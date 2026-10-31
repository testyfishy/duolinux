#!/bin/sh
# Why does Tailscale show disconnected?
set -u
echo "=== service"
echo "  tailscaled: $(systemctl is-active tailscaled) / $(systemctl is-enabled tailscaled)"
systemctl status tailscaled --no-pager 2>/dev/null | tail -6 | sed 's/^/  /'

echo
echo "=== status"
tailscale status 2>&1 | head -6 | sed 's/^/  /'
echo "  ip: $(tailscale ip -4 2>&1 | head -1)"
echo "  backend: $(tailscale status --json 2>/dev/null | grep -o '"BackendState":"[^"]*"' | head -1)"

echo
echo "=== network path"
echo "  tun: $(ip -brief addr show tailscale0 2>/dev/null || echo 'no tailscale0')"
echo "  route: $(ip route show table all 2>/dev/null | grep -c tailscale)"
echo "  dns: $(systemctl is-active systemd-resolved)"

echo
echo "=== can we reach the control plane?"
timeout 8 curl -s -o /dev/null -w "  login.tailscale.com: %{http_code}\n" https://login.tailscale.com 2>&1
timeout 8 curl -s -o /dev/null -w "  controlplane.tailscale.com: %{http_code}\n" https://controlplane.tailscale.com 2>&1

echo
echo "=== recent tailscaled log"
journalctl -u tailscaled --since '-30 min' --no-pager 2>/dev/null | tail -12 | sed 's/^/  /'
