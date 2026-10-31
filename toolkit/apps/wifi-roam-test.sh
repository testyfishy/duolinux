#!/bin/sh
# Decide why the device stays on the weak 5 GHz BSSID.
#   1. unpin the band, reconnect
#   2. force a roam to the strong 2.4 GHz BSSID
#   3. watch whether it stays there or the router pushes it back
# Finally restore the pin, whatever happened.
set -u
LOG=/tmp/wifi-roam.log
CON=PrivateA
STRONG=02:00:00:00:00:30     # 2.4 GHz, ch 6
WEAK=02:00:00:00:00:34       # 5 GHz, ch 36

: > "$LOG"
say() { echo "$(date +%H:%M:%S) $*" >> "$LOG"; }

say "=== start: $(iw dev wlan0 link 2>/dev/null | grep -E 'freq|signal|bitrate' | tr '\n' ' ')"

say "=== unpinning band"
nmcli connection modify "$CON" 802-11-wireless.band "" >>"$LOG" 2>&1
nmcli connection down "$CON" >>"$LOG" 2>&1
sleep 3
nmcli connection up "$CON" >>"$LOG" 2>&1
sleep 6
say "after reconnect: $(iw dev wlan0 link 2>/dev/null | grep -E 'freq|signal' | tr '\n' ' ')"

say "=== can we talk to wpa_supplicant?"
if command -v wpa_cli >/dev/null 2>&1; then
    wpa_cli -i wlan0 status >>"$LOG" 2>&1
    say "bgscan: $(wpa_cli -i wlan0 get_network 0 bgscan 2>&1)"
else
    say "wpa_cli not installed"
fi

say "=== forcing a roam to the strong 2.4 GHz BSSID"
if command -v wpa_cli >/dev/null 2>&1; then
    wpa_cli -i wlan0 roam "$STRONG" >>"$LOG" 2>&1
else
    say "cannot force roam without wpa_cli"
fi

for i in 1 2 3 4 5 6; do
    sleep 5
    say "t+${i}0s: $(iw dev wlan0 link 2>/dev/null | grep -E 'freq|signal' | tr '\n' ' ')"
done

say "=== final: is it still on the strong BSSID, or pushed back to 5 GHz?"
BSSID=$(iw dev wlan0 link 2>/dev/null | awk '/Connected to/{print $3}')
case "$BSSID" in
    "$STRONG") say "RESULT: stayed on 2.4 GHz -> client-side roam works, router is not forcing us back" ;;
    "$WEAK")   say "RESULT: pushed back to 5 GHz -> the router is band-steering" ;;
    *)         say "RESULT: on $BSSID" ;;
esac

say "=== restoring the 2.4 GHz pin"
nmcli connection modify "$CON" 802-11-wireless.band bg >>"$LOG" 2>&1
nmcli connection down "$CON" >>"$LOG" 2>&1
sleep 2
nmcli connection up "$CON" >>"$LOG" 2>&1
sleep 5
say "restored: $(iw dev wlan0 link 2>/dev/null | grep -E 'freq|signal' | tr '\n' ' ')"
say "DONE"
