#!/bin/sh
set -u
echo "=== Wi-Fi: what bands are actually visible"
nmcli -f SSID,BSSID,CHAN,FREQ,SIGNAL,SECURITY dev wifi list 2>/dev/null | head -20

echo
echo "=== current connection"
nmcli -f GENERAL.CONNECTION,GENERAL.STATE,AP,CHAN dev show wlan0 2>/dev/null | head -8
iw dev wlan0 link 2>/dev/null | grep -E "SSID|freq|signal|bitrate"

echo
echo "=== band-steering / roaming config in NetworkManager"
nmcli -f 802-11-wireless.band,802-11-wireless.bssid,802-11-wireless.ssid connection show "$(nmcli -t -f NAME connection show --active | head -1)" 2>/dev/null
echo "  bgscan support: $(nmcli connection show "$(nmcli -t -f NAME connection show --active | head -1)" 2>/dev/null | grep -c bgscan)"

echo
echo "=== keyboard: how is wvkbd launched, and how tall is the bottom screen now"
grep -rn "wvkbd\|duo-osk" /etc/xdg/autostart/*.desktop /home/duo/.config/autostart/*.desktop 2>/dev/null | head -5
echo "--- kscreen outputs:"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 kscreen-doctor -j' 2>/dev/null | grep -E '"name"|"scale"|"geometry"|"size"' | head -20
