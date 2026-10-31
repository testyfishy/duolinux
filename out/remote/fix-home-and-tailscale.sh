#!/bin/sh
# Fix home ownership (Firefox cannot create its profile otherwise) and the
# tailscaled service, then verify both.
set -u

echo "=== before:"
ls -ld /home/duo
systemctl is-active tailscaled

echo "=== fix home ownership"
chown -R duo:duo /home/duo
ls -ld /home/duo
echo "root-owned entries left in home: $(find /home/duo ! -user duo 2>/dev/null | wc -l)"

echo "=== tailscaled status"
systemctl status tailscaled --no-pager -n 8 2>&1 | tail -12
echo "--- journal:"
journalctl -u tailscaled -n 15 --no-pager 2>&1 | tail -15
systemctl restart tailscaled 2>&1
sleep 6
echo "tailscaled: $(systemctl is-active tailscaled)"
tailscale status 2>&1 | head -3

echo "=== firefox profile creation test"
su - duo -c 'HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 timeout 45 firefox-esr --headless --new-instance --screenshot /tmp/ff-test.png https://example.com' >/tmp/ff-test.log 2>&1
echo "exit=$?"
tail -6 /tmp/ff-test.log
ls -l /tmp/ff-test.png 2>&1
echo "--- profile:"
ls -la /home/duo/.mozilla/firefox/ 2>&1 | head -6

echo "=== tailscale login"
nohup tailscale up --hostname=retro-duo-lite >/tmp/tailscale-up.log 2>&1 &
sleep 10
cat /tmp/tailscale-up.log
