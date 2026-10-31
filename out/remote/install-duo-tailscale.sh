#!/bin/bash
# Install the Tailscale tray indicator for the desktop user.
set -euo pipefail
BIN=/usr/local/bin/duo-tailscale
SRC=$(dirname "$0")/duo-tailscale
[ -f "$SRC" ] || SRC=/tmp/duo-tailscale

install -m 755 "$SRC" "$BIN"

mkdir -p /home/duo/.config/autostart
cat > /home/duo/.config/autostart/duo-tailscale.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Tailscale
Comment=Status and login for Tailscale
Exec=/usr/local/bin/duo-tailscale
Icon=network-vpn
Terminal=false
X-KDE-autostart-after=panel
X-GNOME-Autostart-enabled=true
EOF
chown duo:duo /home/duo/.config/autostart/duo-tailscale.desktop

echo "installed: $BIN"
echo "autostart: /home/duo/.config/autostart/duo-tailscale.desktop"

# Can the desktop user drive the daemon without root? `tailscale status` exits
# non-zero while logged out, so test the state we get back, not the exit code.
if su - duo -c 'tailscale status --json 2>/dev/null' | grep -q '"BackendState"'; then
    echo "user can talk to tailscaled: yes"
else
    echo "user cannot talk to tailscaled: run 'tailscale set --operator=duo'"
fi

# start it in the running session now
pkill -f /usr/local/bin/duo-tailscale 2>/dev/null || true
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 \
    nohup /usr/local/bin/duo-tailscale >/tmp/duo-tailscale.log 2>&1 &' 
sleep 3
echo "process: $(pgrep -fc /usr/local/bin/duo-tailscale)"
echo "--- log:"
tail -5 /tmp/duo-tailscale.log 2>/dev/null || echo "  (empty)"
