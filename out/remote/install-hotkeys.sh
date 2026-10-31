#!/bin/bash
# Install Guide-based pad hotkeys and the mouse-mode profile.
set -u

install -m 755 /tmp/padhotkeys /usr/local/bin/padhotkeys
python3 -c 'import ast; ast.parse(open("/usr/local/bin/padhotkeys").read())' && echo "python ok"

echo "=== add the mouse target to their device profile"
python3 - <<'PY'
import pathlib
p = pathlib.Path("/usr/share/inputplumber/devices/40-retroid_duolite.yaml")
t = p.read_text()
if "mouse" not in t.split("target_devices:")[-1]:
    t = t.replace("target_devices:\n  - ds5\n  - keyboard",
                  "target_devices:\n  - ds5\n  - keyboard\n  - mouse")
    p.write_text(t)
print(t.split("target_devices:")[-1].strip())
PY

echo "=== profiles: gamepad (copy of default) + mouse"
mkdir -p /etc/inputplumber/profiles
cp -n /usr/share/inputplumber/profiles/default.yaml /etc/inputplumber/profiles/gamepad.yaml
cat > /etc/inputplumber/profiles/mouse.yaml <<'EOF'
version: 1
kind: DeviceProfile
name: Duo mouse mode
mapping:
  - name: Right stick pointer
    source_event:
      gamepad:
        axis:
          name: RightStick
    target_events:
      - mouse:
          motion:
            speed_pps: 900
  - name: R1 left click
    source_event:
      gamepad:
        button: RightBumper
    target_events:
      - mouse:
          button: Left
  - name: L1 right click
    source_event:
      gamepad:
        button: LeftBumper
    target_events:
      - mouse:
          button: Right
EOF

echo "=== service"
cat > /etc/systemd/system/duo-padhotkeys.service <<'EOF'
[Unit]
Description=Duo Lite pad hotkeys (Guide modifier)
After=inputplumber.service graphical.target
Wants=inputplumber.service

[Service]
Type=simple
ExecStart=/usr/local/bin/padhotkeys
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now duo-padhotkeys.service 2>&1 | tail -2
sleep 3
systemctl is-active duo-padhotkeys
journalctl -u duo-padhotkeys -n 10 --no-pager 2>&1 | tail -6

echo "=== inputplumber still healthy after the profile edit?"
systemctl is-active inputplumber
tail -5 /var/log/syslog 2>/dev/null | grep -i plumber || true
