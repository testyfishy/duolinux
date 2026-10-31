#!/bin/bash
# Vboard: an existing Plasma/Wayland on-screen keyboard that sends keys through
# uinput. Installing the upstream Debian package first, before forking anything.
set -u
export DEBIAN_FRONTEND=noninteractive
cd /tmp
curl -L --fail -o vboard.deb \
  https://github.com/archisman-panigrahi/vboard/releases/download/v2.7.0/vboard_2.7.0-1_all.deb || exit 1
ls -l vboard.deb

apt-get -o Acquire::ForceIPv4=true install -y /tmp/vboard.deb 2>&1 | tail -8

echo "=== installed files"
dpkg -L vboard 2>/dev/null | grep -E "bin/|udev|layouts|desktop" | head -12
echo "=== uinput rule"
cat /etc/udev/rules.d/70-vboard-uinput.rules 2>/dev/null || echo "  (none)"
echo "=== kwin rules added?"
grep -c "vboard" /home/duo/.config/kwinrulesrc 2>/dev/null || echo "  0"
echo "=== deps present"
python3 -c "import uinput, gi; print('python deps ok')" 2>&1 | tail -2
