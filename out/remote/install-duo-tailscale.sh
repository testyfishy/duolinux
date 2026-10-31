#!/bin/bash
# Install a Tailscale tray indicator.
#
# Prefer Tailscale's own `tailscale systray` (Go, ~25 MiB, maintained upstream).
# Fall back to our GTK client (~32 MiB) only if the subcommand is unavailable,
# which can happen on older releases.
set -euo pipefail

if tailscale systray --help >/dev/null 2>&1; then
    EXEC="/usr/bin/tailscale systray"
    echo "using the upstream systray: tailscale systray"
else
    install -m 755 "$(dirname "$0")/duo-tailscale" /usr/local/bin/duo-tailscale
    EXEC="/usr/local/bin/duo-tailscale"
    echo "upstream systray unavailable, installed our GTK client"
fi

# The tray talks to the daemon through the local socket; a non-root user needs
# to be the operator for connect/disconnect to work.
if ! tailscale status --json 2>/dev/null | grep -q '"BackendState"'; then
    echo "note: run 'tailscale set --operator=duo' so the tray can control the daemon"
fi

mkdir -p /home/duo/.config/autostart
cat > /home/duo/.config/autostart/duo-tailscale.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Tailscale
Comment=Status and login for Tailscale
Exec=$EXEC
Icon=network-vpn
Terminal=false
X-KDE-autostart-after=panel
X-GNOME-Autostart-enabled=true
EOF
chown duo:duo /home/duo/.config/autostart/duo-tailscale.desktop
echo "autostart: $EXEC"

# Restart it in the running session
su - duo -c 'pkill -f "/usr/local/bin/duo-tailscale" ; pkill -f "tailscale systray"' 2>/dev/null || true
sleep 1
su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 \
    nohup $EXEC >/tmp/duo-tailscale.log 2>&1 &"
sleep 4

for p in $(pgrep -f "tailscale systray|duo-tailscale" 2>/dev/null); do
    echo "  pid $p: pss=$(awk '/^Pss:/{print $2}' /proc/$p/smaps_rollup 2>/dev/null) kB  $(tr '\0' ' ' < /proc/$p/cmdline | cut -c1-40)"
done
