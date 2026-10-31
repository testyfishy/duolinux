#!/bin/bash
# Step 0: lockout safety checks. Step 1: clock, then install apps.
set -u

echo "=== 1. NetworkManager must not manage usb0"
nmcli -t dev status | grep usb0 || true
ls -l /etc/NetworkManager/conf.d/ 2>/dev/null
grep -r unmanaged /etc/NetworkManager/conf.d/ 2>/dev/null

echo "=== 2. what binds :2222 and :22"
ss -ltnp 2>/dev/null | grep -E ':2222|:22 ' || true

echo "=== 3. sshd auth policy"
grep -E '^(PasswordAuthentication|PermitRootLogin|PubkeyAuthentication)' /etc/ssh/sshd_config

echo "=== 4. rmtfs mode (partition-backed can write modemst1/2)"
systemctl cat rmtfs | grep -E 'ExecStart|Description'

echo "=== 5. modem partitions present?"
ls -l /dev/disk/by-partlabel/ 2>/dev/null | grep -Ei 'modemst|fsg|fsc' || echo "none visible"

echo "=== 6. back them up read-only if present"
mkdir -p /root/modem-backup
for p in modemst1 modemst2 fsg fsc; do
  d=/dev/disk/by-partlabel/$p
  if [ -e "$d" ]; then
    dd if="$d" of="/root/modem-backup/$p.img" bs=4096 status=none 2>/dev/null \
      && echo "backed up $p ($(stat -c%s /root/modem-backup/$p.img) bytes)"
  fi
done

echo "=== 7. clock before"
date -u

echo "=== 8. time sync service"
systemctl is-enabled systemd-timesyncd 2>&1
