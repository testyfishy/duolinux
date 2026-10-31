#!/bin/sh
# Tailscale: leave the package installed but not running (kernel-blocked).
# Firefox: verify it really starts with a profile in the desktop session.
set -u

systemctl stop tailscaled 2>&1
systemctl disable tailscaled 2>&1 | tail -2
echo "tailscaled: $(systemctl is-active tailscaled) / $(systemctl is-enabled tailscaled 2>&1)"

echo "=== firefox profile:"
ls -ld /home/duo/.mozilla/firefox 2>&1
ls -1 /home/duo/.mozilla/firefox/ 2>&1 | head -4

echo "=== firefox GUI start:"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 nohup firefox-esr --new-instance https://example.com >/tmp/ff-gui.log 2>&1 &'
sleep 25
echo "processes:"
pgrep -a firefox 2>/dev/null | head -3
echo "log:"
grep -viE "^$" /tmp/ff-gui.log | tail -8

echo "=== screenshot:"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 spectacle -b -n -o /tmp/ff-gui.png' 2>&1 | tail -1
ls -l /tmp/ff-gui.png 2>&1

echo "=== journal, profile errors:"
su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 journalctl --user --since '-2 min' --no-pager" 2>&1 | grep -iE "profile|firefox" | tail -6
