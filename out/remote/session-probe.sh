#!/bin/bash
echo "=== how sway starts"
systemctl list-units --all --no-pager 2>/dev/null | grep -iE 'sway|greet|getty|display' | head -10
ls /etc/systemd/system/*.service 2>/dev/null | head -20
echo "--- autologin / profile"
grep -rl 'sway' /etc/profile /etc/profile.d /home/duo/.bash_profile /home/duo/.profile /etc/systemd/system 2>/dev/null | head -10
for f in /home/duo/.bash_profile /home/duo/.profile /etc/profile.d/sway.sh; do
  [ -f "$f" ] && { echo "--- $f"; cat "$f"; }
done
echo "=== apps present"
for b in firefox firefox-esr chromium thunar pcmanfm nautilus mc nano vim htop tailscale syncthing foot fuzzel; do
  printf '%-14s %s\n' "$b" "$(command -v "$b" 2>/dev/null || echo -)"
done
echo "=== users/groups of interest"
id duo
echo "=== sway version"
sway --version 2>&1 | head -2
