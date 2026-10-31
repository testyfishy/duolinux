#!/bin/bash
# Switch the graphical session to KDE Plasma, keeping Sway as a fallback.
set -u

echo "=== confirm plasma is installed"
for b in startplasma-wayland plasmashell systemsettings dolphin konsole; do
    printf '%-22s %s\n' "$b" "$(command -v "$b" 2>/dev/null || echo MISSING)"
done
[ -x /usr/bin/startplasma-wayland ] || { echo "ABORT: plasma not installed"; exit 1; }

echo "=== install SDDM (display manager)"
export DEBIAN_FRONTEND=noninteractive
apt-get -o Acquire::ForceIPv4=true install -y --no-install-recommends sddm 2>&1 | tail -4

echo "=== keep a copy of the current autologin so rollback is easy"
mkdir -p /root/rollback
cp /etc/systemd/system/getty@tty1.service.d/autologin.conf /root/rollback/ 2>/dev/null || true

echo "=== sddm config: autologin duo into Plasma Wayland"
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/90-duo.conf <<'EOF'
[Autologin]
User=duo
Session=plasma

[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot
EOF

echo "=== stop the tty1 autologin fighting the display manager"
rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf
systemctl daemon-reload

echo "=== enable sddm"
systemctl enable sddm 2>&1 | tail -2
systemctl set-default graphical.target 2>&1 | tail -1

echo "=== sessions available"
ls /usr/share/wayland-sessions/ 2>/dev/null
echo
echo "Ready. Reboot to test Plasma. Rollback if needed:"
echo "  systemctl disable sddm"
echo "  cp /root/rollback/autologin.conf /etc/systemd/system/getty@tty1.service.d/"
echo "  systemctl daemon-reload && reboot"
