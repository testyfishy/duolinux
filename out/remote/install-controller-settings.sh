#!/bin/bash
# Install the Controller settings page and apply the default bindings.
set -u
export DEBIAN_FRONTEND=noninteractive
apt-get -o Acquire::ForceIPv4=true install -y --no-install-recommends python3-yaml 2>&1 | tail -2

install -m 755 /tmp/duo-controller /usr/local/bin/duo-controller
install -m 755 /tmp/duo-controller-apply /usr/local/bin/duo-controller-apply
python3 -m py_compile /usr/local/bin/duo-controller /usr/local/bin/duo-controller-apply \
    && echo "both compile"

mkdir -p /etc/duo
cat > /etc/duo/controller.json <<'EOF'
{
  "a": "enter",
  "b": "esc",
  "dpad_down": "down",
  "dpad_left": "left",
  "dpad_right": "right",
  "dpad_up": "up",
  "l1": "click",
  "r1": "right_click",
  "select": "none",
  "start": "none",
  "x": "space",
  "y": "menu"
}
EOF
chmod 644 /etc/duo/controller.json

echo "=== apply"
/usr/local/bin/duo-controller-apply
sleep 3
systemctl is-active inputplumber

echo "=== resulting Duo entries"
grep -A6 'name: Duo ' /etc/inputplumber/profiles/gamepad.yaml | grep -E "name:|button:|keyboard:" | head -40

echo "=== launcher"
cat > /usr/share/applications/duo-controller.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Controller
Comment=Button mappings for the handheld controls
Exec=/usr/local/bin/duo-controller
Icon=input-gaming
Categories=Settings;HardwareSettings;
EOF
chmod 644 /usr/share/applications/duo-controller.desktop
update-desktop-database /usr/share/applications 2>/dev/null || true
echo "installed"
