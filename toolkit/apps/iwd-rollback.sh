#!/bin/sh
# Roll back the iwd trial over the USB link and collect the crash evidence.
set -u
LOG=/tmp/iwd-rollback.log
: > "$LOG"
say() { echo "$*" >> "$LOG"; }

say "=== kernel messages about the wifi driver"
dmesg | grep -iE "ath10k|wlan0|firmware crashed|fatal" | tail -15 >> "$LOG"

say "=== removing the iwd backend"
rm -f /etc/NetworkManager/conf.d/iwd.conf
systemctl disable --now iwd >>"$LOG" 2>&1
systemctl enable --now wpa_supplicant >>"$LOG" 2>&1
systemctl restart NetworkManager >>"$LOG" 2>&1
sleep 5

say "=== reloading the driver if it is wedged"
if ! iw dev wlan0 link >/dev/null 2>&1; then
    modprobe -r ath10k_snoc ath10k_core 2>>"$LOG"
    sleep 2
    modprobe ath10k_snoc 2>>"$LOG"
    sleep 8
fi

say "=== restoring the 2.4 GHz pin and reconnecting"
nmcli connection modify PrivateA 802-11-wireless.band bg >>"$LOG" 2>&1
nmcli connection up PrivateA >>"$LOG" 2>&1
sleep 6

say "=== state"
say "  global: $(nmcli -t -f STATE g 2>/dev/null)"
say "  link:   $(iw dev wlan0 link 2>/dev/null | grep -E 'freq|signal|bitrate' | tr '\n' ' ')"
say "  wpa:    $(systemctl is-active wpa_supplicant)  iwd: $(systemctl is-active iwd 2>/dev/null)"
say "DONE"
cat "$LOG"
