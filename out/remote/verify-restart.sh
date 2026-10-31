#!/bin/sh
# Restart the shell the normal way and confirm a clean idle panel.
set -u

echo "=== autostart entries:"
ls -1 /home/duo/.config/autostart/ 2>/dev/null
echo "=== anything launching plasmashell besides systemd?"
grep -rls "plasmashell" /home/duo/.config/autostart /home/duo/.config/plasma-workspace 2>/dev/null
echo "=== plasma-workspace env scripts:"
ls -1 /home/duo/.config/plasma-workspace/env/ 2>/dev/null || echo none

su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user restart plasma-plasmashell.service' 2>&1
sleep 35

P=$(pgrep -x plasmashell | head -1)
echo "=== instances: $(pgrep -xc plasmashell) pid=$P"
echo "=== CPU:"
top -H -b -d 20 -n 2 -p "$P" | awk '/PID USER/{c++} c==2' | head -2
CACHE=$(ls -1 /home/duo/.cache/ksycoca6_* | head -1)
echo "=== cache mtime: $(stat -c '%y' "$CACHE")"
echo "=== journal (errors since restart):"
su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 journalctl --user -u plasma-plasmashell.service --since '-1 min' --no-pager" 2>&1 | grep -iE "error|warning|cannot|failed" | head -6
echo "=== screenshot:"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 spectacle -b -n -o /tmp/panel4.png' 2>&1 | tail -2
ls -l /tmp/panel4.png 2>&1
