#!/bin/sh
# Start Tsukimi and report the classes of its windows so a KWin rule can target
# the mpv player (video) rather than the library UI.
set -u
pkill -f "moe.tsuna.tsukimi" 2>/dev/null
sleep 2
su - duo -c "HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 \
    nohup flatpak run moe.tsuna.tsukimi >/tmp/tsukimi.log 2>&1 &"
sleep 8

echo "=== processes"
pgrep -af "tsukimi|mpv" | cut -c1-90 | sed 's/^/  /'

echo
echo "=== kwin windows (class / caption)"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 qdbus6 org.kde.KWin /KWin supportInformation' 2>/dev/null \
  | sed -n '/Windows:/,/^$/p' | grep -iE "class|caption|resource" | head -20 | sed 's/^/  /'

echo
echo "=== log tail"
tail -3 /tmp/tsukimi.log 2>/dev/null | sed 's/^/  /'
