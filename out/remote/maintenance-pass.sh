#!/bin/sh
# Maintenance pass: remove vboard, install Tailscale, drop the extra battery
# applet in favour of Plasma's own tray indicator, and probe Firefox.
set -u

echo "=== 1. purge vboard"
DEBIAN_FRONTEND=noninteractive apt-get purge -y vboard 2>&1 | tail -6
echo "vboard packages left: $(dpkg -l vboard 2>/dev/null | grep -c '^ii')"
echo "desktop entry left: $(ls /usr/share/applications | grep -c vboard)"

echo "=== 2. install tailscale"
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg && echo "key ok"
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list -o /etc/apt/sources.list.d/tailscale.list && echo "list ok"
cat /etc/apt/sources.list.d/tailscale.list
apt-get update 2>&1 | tail -3
DEBIAN_FRONTEND=noninteractive apt-get install -y tailscale 2>&1 | tail -6
command -v tailscale && tailscale version 2>&1 | head -2
systemctl enable --now tailscaled 2>&1 | tail -2
sleep 4
echo "tailscaled: $(systemctl is-active tailscaled)"

echo "=== 3. drop the standalone battery applet"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user stop plasma-plasmashell.service' 2>&1
sleep 3
python3 /tmp/drop-panel-battery.py 2>&1
chown duo:duo /home/duo/.config/plasma-org.kde.plasma.desktop-appletsrc
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user start plasma-plasmashell.service' 2>&1
sleep 35

cat > /tmp/l6.js <<'EOS'
print(panels()[0].widgets().map(function (w) { return w.type; }).join(","));
EOS
echo "=== panel applets:"
su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \"\$(cat /tmp/l6.js)\"" 2>&1 | head -2

echo "=== 4. tailscale login (background, needs approval)"
nohup tailscale up --hostname=retro-duo-lite >/tmp/tailscale-up.log 2>&1 &
sleep 8
cat /tmp/tailscale-up.log

echo "=== 5. firefox probe"
echo "-- graphics packages:"
dpkg -l 2>/dev/null | grep -iE "libva|va-driver|mesa-va" | awk '{print $2, $3}' | head -8
echo "-- profile:"
ls /home/duo/.mozilla/firefox/ 2>/dev/null | head
grep -hE "gfx.webrender|media.ffmpeg|layers.acceleration|widget.dmabuf|gfx.canvas" /home/duo/.mozilla/firefox/*/prefs.js 2>/dev/null | head -8
echo "-- launch test, 20 s:"
su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 MOZ_ENABLE_WAYLAND=1 timeout 20 firefox-esr --new-instance about:blank" >/tmp/ff.log 2>&1
echo "exit=$?"
tail -15 /tmp/ff.log
