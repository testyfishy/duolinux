#!/bin/bash
set -u
install -m 755 /tmp/duo-wifi /usr/local/bin/duo-wifi
sh -n /usr/local/bin/duo-wifi && echo "syntax ok"

echo "=== does fuzzel support --password?"
fuzzel --version 2>&1 | head -2
fuzzel --help 2>&1 | grep -i password | head -2

echo "=== root helper can drive NetworkManager without polkit?"
sudo -n nmcli -t -f RUNNING general 2>&1 | head -2
sudo -n nmcli dev wifi list 2>&1 | head -3

echo "=== network count the picker will show"
sudo -n nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null | awk -F: 'NF>=3 && $1!="" && !seen[$1]++' | wc -l
