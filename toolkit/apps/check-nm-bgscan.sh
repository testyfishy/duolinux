#!/bin/sh
set -u
echo "=== NetworkManager version"
nmcli --version

echo
echo "=== does this NM expose bgscan?"
nmcli -f 802-11-wireless.bgscan connection show "PrivateA" 2>&1 | head -3
echo "  (empty/error means the property does not exist in this build)"

echo
echo "=== roaming-related properties that DO exist"
nmcli connection show "PrivateA" 2>/dev/null | grep -iE "band|bssid|bgscan|powersave|ap-" | head -8

echo
echo "=== driver"
readlink -f /sys/class/net/wlan0/device/driver 2>/dev/null | xargs -r basename
echo "  firmware: $(dmesg | grep -iE 'ath10k.*firmware|wcn3990' | head -2)"

echo
echo "=== measured signal on both APs of the same SSID"
nmcli -f BSSID,CHAN,FREQ,SIGNAL dev wifi list 2>/dev/null | grep -E "90:CA:FA:5D:94:(30|34)"
