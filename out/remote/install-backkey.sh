#!/bin/bash
# Install the back-button listener as a user service, then test it.
set -u
install -m 755 /tmp/duo-backkey /usr/local/bin/duo-backkey
python3 -m py_compile /usr/local/bin/duo-backkey && echo "compiles"

mkdir -p /home/duo/.config/systemd/user
cat > /home/duo/.config/systemd/user/duo-backkey.service <<'EOF'
[Unit]
Description=Back button toggles the on-screen keyboard
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/local/bin/duo-backkey
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF
chown -R duo:duo /home/duo/.config/systemd/user /usr/local/bin/duo-backkey
chmod 644 /home/duo/.config/systemd/user/duo-backkey.service

su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user daemon-reload'
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user enable --now duo-backkey.service' 2>&1 | tail -2
sleep 3
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user status duo-backkey.service --no-pager' 2>&1 | head -8

echo "=== test: inject F1 on the DualSense device"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 python3 /tmp/inject-key.py "Sony Interactive Entertainment DualSense Wireless Controller" 59'
sleep 2
ls /run/user/1000/duo-osk.on 2>/dev/null && echo "state: shown" || echo "state: hidden"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 python3 /tmp/inject-key.py "Sony Interactive Entertainment DualSense Wireless Controller" 59'
sleep 2
ls /run/user/1000/duo-osk.on 2>/dev/null && echo "state: shown" || echo "state: hidden"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 journalctl --user -u duo-backkey -n 5 --no-pager' 2>&1 | tail -5
