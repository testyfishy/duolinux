#!/bin/sh
# Trial of iwd as the NetworkManager backend, with automatic rollback.
#
# iwd ranks access points by estimated data rate and exposes a 5 GHz band
# modifier, which is what wpa_supplicant lacks here. ath10k_snoc coverage is
# thinner, so this script proves connectivity after the switch and reverts
# itself if it fails. Everything is logged to /tmp/iwd-trial.log.
set -u
LOG=/tmp/iwd-trial.log
CON=PrivateA
GW=192.168.86.1
say() { echo "$(date +%H:%M:%S) $*" >> "$LOG"; }

: > "$LOG"
say "=== start: $(iw dev wlan0 link 2>/dev/null | grep -E 'freq|signal' | tr '\n' ' ')"

if ! command -v iwd >/dev/null 2>&1; then
    say "installing iwd"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq iwd >>"$LOG" 2>&1 || { say "install failed"; exit 1; }
fi

# Let iwd choose the band, otherwise the pin defeats the point.
nmcli connection modify "$CON" 802-11-wireless.band "" >>"$LOG" 2>&1

mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/iwd.conf <<'EOF'
[device]
wifi.backend=iwd
EOF

say "switching backend"
systemctl disable --now wpa_supplicant >>"$LOG" 2>&1
systemctl enable --now iwd >>"$LOG" 2>&1
systemctl restart NetworkManager >>"$LOG" 2>&1
sleep 5

# wait up to 60 s for a working link
ok=0
for i in $(seq 1 12); do
    sleep 5
    st=$(nmcli -t -f STATE g 2>/dev/null)
    ping -c1 -W2 "$GW" >/dev/null 2>&1 && ok=1
    say "t+$((i*5))s state=$st ping=$ok link=$(iw dev wlan0 link 2>/dev/null | grep -E 'freq|signal' | tr '\n' ' ')"
    [ "$ok" = 1 ] && break
done

if [ "$ok" = 1 ]; then
    say "RESULT: iwd works; connection is up"
    say "iwd link: $(iw dev wlan0 link 2>/dev/null | tr '\n' ' ')"
    exit 0
fi

say "RESULT: no connectivity with iwd; rolling back"
rm -f /etc/NetworkManager/conf.d/iwd.conf
systemctl disable --now iwd >>"$LOG" 2>&1
systemctl enable --now wpa_supplicant >>"$LOG" 2>&1
systemctl restart NetworkManager >>"$LOG" 2>&1
sleep 5
nmcli connection modify "$CON" 802-11-wireless.band bg >>"$LOG" 2>&1
nmcli connection up "$CON" >>"$LOG" 2>&1
sleep 5
say "rolled back: state=$(nmcli -t -f STATE g 2>/dev/null) link=$(iw dev wlan0 link 2>/dev/null | grep -E 'freq|signal' | tr '\n' ' ')"
say "DONE"
