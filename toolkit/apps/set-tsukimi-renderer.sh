#!/bin/sh
# Switch Tsukimi's mpv renderer away from gpu-next/Vulkan (which Turnip 1.0.305
# cannot satisfy) and restart it.
set -u
K=/home/duo/.var/app/moe.tsuna.tsukimi/config/glib-2.0/settings/keyfile
VALUE="${1:-1}"

pkill -f moe.tsuna.tsukimi 2>/dev/null
sleep 2
[ -f "$K" ] && cp -p "$K" /tmp/tsukimi-keyfile.bak

sed -i "s/^mpv-renderer=.*/mpv-renderer=$VALUE/" "$K"
chown duo:duo "$K"
echo "  mpv-renderer now: $(grep '^mpv-renderer=' "$K")"

su - duo -c "HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 \
    nohup flatpak run moe.tsuna.tsukimi >/tmp/tsukimi.log 2>&1 &"
sleep 8
echo "  running: $(pgrep -fc tsukimi)"
