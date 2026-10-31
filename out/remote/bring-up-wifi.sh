#!/bin/bash
# Install libqrtr, start the Qualcomm stack, boot the modem, load ath10k_snoc.
set -u
install -m 644 /tmp/libqrtr.so.1.2 /usr/lib/libqrtr.so.1.2
ln -sf libqrtr.so.1.2 /usr/lib/libqrtr.so.1
ldconfig
echo "=== linkage check"
ldd /usr/bin/qrtr-ns 2>&1 | grep -E 'qrtr|not found'
ldd /usr/bin/rmtfs 2>&1 | grep -E 'qrtr|not found'
ldd /usr/bin/pd-mapper 2>&1 | grep -E 'qrtr|not found'

systemctl daemon-reload
systemctl reset-failed qrtr-ns pd-mapper rmtfs tqftpserv 2>/dev/null

for s in qrtr-ns pd-mapper tqftpserv rmtfs; do
  systemctl start "$s" 2>&1
  sleep 1
done
echo "=== services"
for s in qrtr-ns pd-mapper tqftpserv rmtfs; do
  printf '%-12s %s\n' "$s" "$(systemctl is-active "$s" 2>&1)"
done

echo "=== start the modem remoteproc"
if [ -w /sys/class/remoteproc/remoteproc0/state ]; then
  echo start > /sys/class/remoteproc/remoteproc0/state 2>&1 || echo "write failed"
  for i in $(seq 1 10); do
    st=$(cat /sys/class/remoteproc/remoteproc0/state)
    echo "  modem state: $st"
    [ "$st" = "running" ] && break
    sleep 1
  done
fi

echo "=== ath10k_snoc reload"
modprobe -r ath10k_snoc 2>/dev/null
modprobe ath10k_snoc 2>&1
sleep 10

echo "=== interfaces"
ip -br addr
echo "=== dmesg (wifi/modem)"
dmesg 2>/dev/null | grep -iE 'ath10k|wcn|wlfw|qmi|remoteproc|modem|rmtfs|qrtr' | tail -30
