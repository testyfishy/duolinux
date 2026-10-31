#!/bin/bash
# Current Qualcomm Wi-Fi state on the Duo.
echo "=== kernel"; uname -r
echo "=== remoteproc devices"
for r in /sys/class/remoteproc/*; do
  [ -e "$r" ] || continue
  printf '%s name=%s state=%s fw=%s\n' "$r" "$(cat "$r/name" 2>/dev/null)" "$(cat "$r/state" 2>/dev/null)" "$(cat "$r/firmware" 2>/dev/null)"
done
echo "=== services"
for s in qrtr-ns rmtfs pd-mapper tqftpserv wpa_supplicant NetworkManager; do
  printf '%-16s %s\n' "$s" "$(systemctl is-active "$s" 2>&1)"
done
echo "=== binaries"
for b in rmtfs pd-mapper tqftpserv qrtr-ns wpa_supplicant nmcli iw; do
  printf '%-16s %s\n' "$b" "$(command -v "$b" 2>/dev/null || echo MISSING)"
done
echo "=== modem firmware present?"
for f in /lib/firmware/qcom/sm6125/modem.mbn /lib/firmware/qcom/sm6125/mba.mbn \
         /lib/firmware/qcom/sm6125/wlanmdsp.mbn /lib/firmware/ath10k/WCN3990/hw1.0/board-2.bin; do
  printf '%-58s %s\n' "$f" "$([ -e "$f" ] && echo yes || echo MISSING)"
done
echo "=== load ath10k_snoc"
modprobe ath10k_snoc 2>&1
sleep 4
echo "=== interfaces"
ip -br addr
echo "=== rfkill"
rfkill list 2>&1
echo "=== dmesg tail"
dmesg 2>/dev/null | grep -iE 'ath10k|wcn|rproc|remoteproc|qmi|wlfw|qrtr|mba|modem' | tail -40
echo "=== done"
