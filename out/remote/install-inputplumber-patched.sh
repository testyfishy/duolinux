#!/bin/bash
# Install the patched InputPlumber next to the ROCKNIX binary, with a drop-in so
# rollback is deleting one file. Never runs `make install`: that would overwrite
# the udev, polkit and D-Bus files ROCKNIX ships and the unit depends on.
set -u
BIN=/root/InputPlumber/target/release/inputplumber

[ -x "$BIN" ] || { echo "build missing: $BIN"; exit 1; }
"$BIN" --version 2>&1 | head -1

echo "=== keep a copy of the current binary"
mkdir -p /root/inputplumber-backup
[ -f /root/inputplumber-backup/inputplumber ] || cp /usr/bin/inputplumber /root/inputplumber-backup/

echo "=== install"
install -m 755 "$BIN" /usr/local/bin/inputplumber
mkdir -p /etc/systemd/system/inputplumber.service.d
cat > /etc/systemd/system/inputplumber.service.d/override.conf <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/local/bin/inputplumber
Environment=LOG_LEVEL=warn
EOF
systemctl daemon-reload
systemctl restart inputplumber
sleep 4
systemctl is-active inputplumber
journalctl -u inputplumber -n 5 --no-pager | tail -3
echo
echo "rollback: rm -rf /etc/systemd/system/inputplumber.service.d && systemctl daemon-reload && systemctl restart inputplumber"
