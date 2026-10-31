#!/bin/bash
# Open a terminal on the device with the password prompt already running.
# The password is typed on the device keyboard and never passes through SSH.
set -u
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 setsid konsole -e bash -c "sudo passwd duo; echo; echo Done - close this window; sleep 30" >/dev/null 2>&1 < /dev/null &'
sleep 4
echo "=== konsole running:"; pgrep -af konsole | head -2
echo "=== current account state (no hashes shown):"
passwd -S duo
echo "=== current sudoers drops:"
ls /etc/sudoers.d/ 2>/dev/null
for f in /etc/sudoers.d/*; do echo "--- $f"; grep -v "^#" "$f" 2>/dev/null | grep -v "^$"; done
