#!/bin/sh
# Retry the Tailscale login, capture the auth URL, and check the panel.
set -u

echo "=== daemon:"
systemctl is-active tailscaled
tailscale status 2>&1 | head -3

echo "=== login:"
nohup tailscale up --hostname=retro-duo-lite --accept-dns=false >/tmp/tailscale-up.log 2>&1 &
sleep 10
cat /tmp/tailscale-up.log

echo "=== firefox headless render test:"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 MOZ_ENABLE_WAYLAND=1 timeout 60 firefox-esr --headless --new-instance --screenshot /tmp/ff-headless.png https://example.com' >/tmp/ff-headless.log 2>&1
echo "exit=$?"
tail -5 /tmp/ff-headless.log
ls -l /tmp/ff-headless.png 2>&1

echo "=== profile now:"
ls /home/duo/.mozilla/firefox/ 2>/dev/null | head -5

echo "=== screenshot:"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 spectacle -b -n -o /tmp/panel5.png' 2>&1 | tail -2
ls -l /tmp/panel5.png 2>&1
