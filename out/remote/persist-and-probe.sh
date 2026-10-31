#!/bin/bash
# Persist the Wi-Fi bring-up, then report input devices and display connectors.
set -u

cat > /usr/local/bin/duo-modem <<'EOF'
#!/bin/sh
# Start the Qualcomm modem (which hosts the WCN3990 Wi-Fi firmware), then load
# ath10k_snoc and wait for wlan0.
set -u
STATE=/sys/class/remoteproc/remoteproc0/state
FW=/sys/class/remoteproc/remoteproc0/firmware
if [ -e "$STATE" ]; then
  [ "$(cat "$STATE")" = "running" ] || echo start > "$STATE" 2>/dev/null || true
  for i in $(seq 1 15); do
    [ "$(cat "$STATE")" = "running" ] && break
    sleep 1
  done
fi
modprobe ath10k_snoc 2>/dev/null || true
for i in $(seq 1 15); do
  [ -e /sys/class/net/wlan0 ] && break
  sleep 1
done
rfkill unblock wifi 2>/dev/null || true
ip link set wlan0 up 2>/dev/null || true
exit 0
EOF
chmod 755 /usr/local/bin/duo-modem

cat > /etc/systemd/system/duo-modem.service <<'EOF'
[Unit]
Description=Qualcomm modem and WCN3990 Wi-Fi bring-up
After=qrtr-ns.service pd-mapper.service tqftpserv.service rmtfs.service
Wants=qrtr-ns.service pd-mapper.service tqftpserv.service rmtfs.service
Before=NetworkManager.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/duo-modem
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
EOF
chmod 644 /etc/systemd/system/duo-modem.service

systemctl daemon-reload
systemctl enable pd-mapper.service >/dev/null 2>&1
systemctl enable duo-modem.service >/dev/null 2>&1
chmod 644 /usr/lib/systemd/system/qrtr-ns.service /usr/lib/systemd/system/rmtfs.service \
          /usr/lib/systemd/system/tqftpserv.service /usr/lib/systemd/system/pd-mapper.service 2>/dev/null
chmod 644 /etc/systemd/system/rmtfs.service.d/*.conf 2>/dev/null

echo "=== enabled?"
systemctl is-enabled qrtr-ns pd-mapper rmtfs tqftpserv duo-modem 2>&1

echo "=== input devices"
cat /proc/bus/input/devices | awk '/^N: Name=/{name=$0} /^H: Handlers=/{print name"  "$0}' | sed 's/N: Name=//'

echo "=== python evdev available?"
python3 -c 'import evdev; print("evdev", evdev.__version__)' 2>&1 | head -2

echo "=== drm connectors"
for c in /sys/class/drm/card*-*; do
  [ -e "$c" ] || continue
  printf '%-22s status=%-12s enabled=%s\n' "$(basename "$c")" "$(cat "$c/status" 2>/dev/null)" "$(cat "$c/enabled" 2>/dev/null)"
done

echo "=== sway outputs"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 swaymsg -t get_outputs' 2>&1 | head -40
