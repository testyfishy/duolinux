#!/bin/bash
# Inventory ROCKNIX's SYSTEM squashfs: the userspace we want to port.
set -e
MNT=/mnt/rnx
SYS=/mnt/rnxsys
mkdir -p "$SYS"
if ! mountpoint -q "$SYS"; then
  mount -o loop,ro "$MNT/SYSTEM" "$SYS" 2>/dev/null || mount -o ro,loop "$MNT/SYSTEM" "$SYS"
fi

echo "=== root"; ls "$SYS" | head -20
echo "=== qualcomm modem/wifi userspace"
for b in rmtfs pd-mapper tqftpserv qrtr-ns qrtr-lookup; do
  printf '%-14s %s\n' "$b" "$(find "$SYS"/usr -name "$b" -type f 2>/dev/null | head -1)"
done
echo "=== units"
find "$SYS"/usr/lib/systemd/system "$SYS"/etc/systemd/system -maxdepth 1 -type f 2>/dev/null \
  | grep -Ei 'rmtfs|pd-mapper|tqftpserv|qrtr|wpa|wifi|bluetooth' | sort
echo "=== sm6125 firmware"
ls -la "$SYS"/usr/lib/firmware/qcom/sm6125/ 2>/dev/null | head -25
echo "=== ath10k WCN3990"
ls "$SYS"/usr/lib/firmware/ath10k/WCN3990/hw1.0/ 2>/dev/null
echo "=== input related"
find "$SYS"/usr/lib/udev "$SYS"/etc/udev -type f 2>/dev/null | grep -Ei 'input|gamepad|joystick|retroid' | head -20
find "$SYS"/usr/share -maxdepth 3 -type d -iname '*input*' 2>/dev/null | head -10
echo "=== retroid specific strings in configs"
grep -ril 'retroid' "$SYS"/usr/lib/udev "$SYS"/etc 2>/dev/null | head -20
echo "=== done"
