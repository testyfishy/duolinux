#!/bin/bash
# Fix the three reported problems:
#   1. keyboard would not close (the lock fd leaked into the wvkbd child, so the
#      next invocation waited 5 s on flock and exited)
#   2. slow first open (nothing pre-created the hidden keyboard)
#   3. lid close did nothing (powerdevil suppresses it: DP-1 looks external)
set -u

echo "=== 1. do not leak the flock fd into the keyboard process"
python3 - <<'PY'
import pathlib
p = pathlib.Path("/usr/local/bin/duo-osk")
t = p.read_text()
old = "        --hidden >/dev/null 2>&1 &"
new = "        --hidden >/dev/null 2>&1 9>&- &"
if old in t and new not in t:
    t = t.replace(old, new)
    p.write_text(t)
    print("lock fd closed in the child")
else:
    print("already patched or anchor missing")
PY
bash -n /usr/local/bin/duo-osk && echo "duo-osk syntax ok"

echo "=== 2. pre-create the hidden keyboard at login"
mkdir -p /home/duo/.config/autostart
cat > /home/duo/.config/autostart/duo-osk.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=On-screen keyboard (preload)
Comment=Create the hidden keyboard so the first toggle is instant
Exec=/usr/local/bin/duo-osk --init
X-KDE-autostart-after=panel
NoDisplay=true
EOF
chown -R duo:duo /home/duo/.config/autostart

echo "=== 3. lid daemon"
install -m 755 /tmp/duo-lid /usr/local/bin/duo-lid
python3 -m py_compile /usr/local/bin/duo-lid && echo "duo-lid compiles"
cat > /etc/systemd/system/duo-lid.service <<'EOF'
[Unit]
Description=Suspend when the lid closes
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/duo-lid
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now duo-lid.service 2>&1 | tail -1
sleep 2
systemctl is-active duo-lid
journalctl -u duo-lid -n 3 --no-pager | tail -2

echo "=== 4. restart the keyboard to pick up the lock fix"
su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 /usr/local/bin/duo-osk restart" 2>&1 | tail -1
sleep 1
echo "instances: $(pgrep -c -x wvkbd-mobintl)"
