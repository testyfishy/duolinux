#!/bin/sh
# Keep the stick-as-mouse profile bound to InputPlumber's lifecycle.
#
# duo-mouse-apply loads /etc/inputplumber/profiles/mouse-<stick>.yaml into the
# running InputPlumber daemon over D-Bus (LoadProfilePath). That state lives in
# the daemon, so restarting inputplumber silently drops stick-to-mouse until the
# daemon is told again - which is why the pointer died after a rebuild.
#
# PartOf= makes a restart of inputplumber restart this oneshot too, so the
# profile is re-applied every time the daemon comes back.
set -eu

mkdir -p /etc/systemd/system/duo-mouse.service.d
cat > /etc/systemd/system/duo-mouse.service.d/partof.conf <<'EOF'
[Unit]
PartOf=inputplumber.service
After=inputplumber.service
EOF

systemctl daemon-reload
systemctl restart duo-mouse
sleep 3
systemctl is-active duo-mouse
echo "mouse flag: $(ls /run/user/1000/duo-mouse.on 2>/dev/null || echo missing)"

echo "=== verify the profile is loaded in the daemon"
busctl call org.shadowblip.InputPlumber \
    /org/shadowblip/InputPlumber/CompositeDevice0 \
    org.freedesktop.DBus.Properties GetAll s org.shadowblip.Input.CompositeDevice 2>/dev/null \
    | tr ',' '\n' | grep -iE "profile|name" | head -6 || true
