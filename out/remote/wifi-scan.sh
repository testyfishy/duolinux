#!/bin/bash
set -u
rfkill unblock wifi 2>/dev/null || true
ip link set wlan0 up 2>&1
nmcli radio wifi on 2>&1
sleep 2
echo "=== device status"
nmcli -t dev status 2>&1
echo "=== scan (iw)"
iw dev wlan0 scan 2>&1 | grep -E 'SSID|signal|freq' | head -40
echo "=== scan (nmcli, first 15)"
nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list 2>&1 | head -15
echo "=== dmesg tail"
dmesg | tail -5
