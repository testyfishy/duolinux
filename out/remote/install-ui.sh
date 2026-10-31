#!/bin/bash
# Install the new UI, validate the Sway config, and only then activate it.
set -u

echo "=== install scripts"
for f in duo-display duo-scale duo-apps duo-wifi duo-osk duo-settings; do
  install -m 755 "/tmp/$f" "/usr/local/bin/$f"
done

echo "=== default scale"
mkdir -p /home/duo/.config/duo
if [ ! -f /home/duo/.config/duo/scale.conf ]; then
  printf '1.5\n' > /home/duo/.config/duo/scale.conf
fi
chown -R duo:duo /home/duo/.config
chmod 644 /home/duo/.config/duo/scale.conf

echo "=== i3status config"
mkdir -p /home/duo/.config/i3status
cat > /home/duo/.config/i3status/config <<'EOF'
general {
    colors = true
    interval = 5
}
order += "battery all"
order += "wireless _first_"
order += "ethernet usb0"
order += "disk /"
order += "tztime local"

battery all {
    format = "%status %percentage"
}
wireless _first_ {
    format_up = "wifi %quality"
    format_down = "wifi off"
}
ethernet usb0 {
    format_up = "usb"
    format_down = ""
}
disk / {
    format = "%free free"
}
tztime local {
    format = "%a %H:%M"
}
EOF
chown -R duo:duo /home/duo/.config/i3status

echo "=== validate the new sway config BEFORE installing it"
if sway -C -c /tmp/sway-config 2>&1 | tee /tmp/sway-check.log; then
  echo "config parsed"
fi
if grep -q 'Error on line\|Error(s) loading config' /tmp/sway-check.log; then
  echo "ABORT: config has errors, keeping the old one"
  exit 1
fi

echo "=== install config (keeping a known-good copy)"
[ -f /etc/sway/config ] && cp -n /etc/sway/config /etc/sway/config.known-good
install -m 644 /tmp/sway-config /etc/sway/config
echo "installed"

echo "=== final parse check of the installed file"
sway -C -c /etc/sway/config >/dev/null 2>&1 && echo "installed config OK" || echo "installed config FAILED"
