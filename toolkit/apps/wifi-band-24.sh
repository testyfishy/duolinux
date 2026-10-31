#!/bin/sh
# Pin the PrivateA connection to 2.4 GHz: the 5 GHz AP is at -84 dBm while the
# 2.4 GHz AP on the same SSID is at 99%. Run detached so a dropped SSH link
# cannot abort the change halfway.
set -u
CON="$(nmcli -t -f NAME connection show --active | head -1)"
echo "connection: $CON" > /tmp/wifi-band.log
nmcli connection modify "$CON" 802-11-wireless.band bg >> /tmp/wifi-band.log 2>&1
nmcli connection down "$CON" >> /tmp/wifi-band.log 2>&1
sleep 3
nmcli connection up "$CON" >> /tmp/wifi-band.log 2>&1
sleep 5
{
  echo "--- after"
  iw dev wlan0 link 2>/dev/null | grep -E "SSID|freq|signal|bitrate"
  nmcli -f GENERAL.CONNECTION,AP,CHAN dev show wlan0 2>/dev/null | head -6
} >> /tmp/wifi-band.log 2>&1
