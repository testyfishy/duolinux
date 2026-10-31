#!/bin/bash
echo "=== qrtr-ns status"
systemctl status qrtr-ns --no-pager -l 2>&1 | tail -20
echo "=== qrtr-ns journal"
journalctl -u qrtr-ns -n 30 --no-pager 2>&1 | tail -30
echo "=== rmtfs journal"
journalctl -u rmtfs -n 15 --no-pager 2>&1 | tail -15
echo "=== tqftpserv journal"
journalctl -u tqftpserv -n 15 --no-pager 2>&1 | tail -15
echo "=== qrtr kernel support"
ls /sys/module/qrtr 2>&1 | head -3
ls -l /dev/qrtr* 2>&1 | head -3
cat /proc/net/qrtr/ns 2>&1 | head -5
echo "=== modules"
lsmod | grep -Ei 'qrtr|ath10k|qcom' 
echo "=== done"
