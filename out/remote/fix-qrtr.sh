#!/bin/bash
# Install libqrtr + pd-mapper, then start the Qualcomm stack in the right order.
set -u
chmod 755 /usr/bin/pd-mapper
chmod 644 /usr/lib/libqrtr.so.1.2
ln -sf libqrtr.so.1.2 /usr/lib/libqrtr.so.1
ldconfig

echo "=== linkage"
ldd /usr/bin/pd-mapper | head -5
ldd /usr/bin/qrtr-ns | head -3

systemctl reset-failed qrtr-ns pd-mapper rmtfs tqftpserv 2>/dev/null

echo "=== qrtr-ns"
systemctl start qrtr-ns
sleep 1
systemctl is-active qrtr-ns

echo "=== pd-mapper, tqftpserv, rmtfs"
systemctl start pd-mapper
sleep 1
systemctl start tqftpserv
sleep 1
systemctl start rmtfs
sleep 2

for s in qrtr-ns pd-mapper tqftpserv rmtfs; do
  printf '%-12s %s\n' "$s" "$(systemctl is-active "$s")"
done

echo "=== recent failures (if any)"
for s in qrtr-ns pd-mapper tqftpserv rmtfs; do
  systemctl is-active "$s" >/dev/null 2>&1 || journalctl -u "$s" -n 5 --no-pager 2>&1 | tail -5
done

echo "=== modem remoteproc"
for r in /sys/class/remoteproc/*; do
  [ -e "$r" ] || continue
  echo "$r name=$(cat "$r/name") state=$(cat "$r/state") fw=$(cat "$r/firmware")"
done

echo "=== qrtr services list"
timeout 5 qrtr-lookup 2>&1 | head -10 || true
