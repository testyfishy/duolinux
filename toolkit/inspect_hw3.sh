#!/bin/bash
cd "/mnt/c/Users/user/Documents/Default Project/duolinux/out" || exit 1
D="duolinux-duol.img?offset=537919488"

echo "===== does the KERNEL binary contain the bottom-panel driver match?"
mcopy -o -n -i "duolinux-duol.img@@1048576" ::/KERNEL /tmp/KERNEL 2>/dev/null
ls -l /tmp/KERNEL
for s in "retroidpocket,duolite-bottom-panel" "duolite-bottom-panel" "wcn3990" "ath10k_snoc"; do
  n=$(strings -a /tmp/KERNEL | grep -c -- "$s")
  echo "  '$s' occurrences in KERNEL: $n"
done

echo "===== WCN3990 firmware files:"
debugfs -R "ls /lib/firmware/ath10k/WCN3990/hw1.0" "$D" 2>/dev/null
echo "===== /lib/firmware/qcom:"
debugfs -R "ls /lib/firmware/qcom" "$D" 2>/dev/null

echo "===== wifi/network tools installed:"
for f in /usr/bin/nmtui /usr/bin/nmtui-connect /usr/bin/nmcli /usr/bin/iw /usr/sbin/iw /usr/bin/wpa_cli /usr/bin/networkctl; do
  printf "%-28s " "$f"
  debugfs -R "stat $f" "$D" 2>/dev/null | grep -q "Inode:" && echo present || echo MISSING
done

echo "===== has the kernel got cfg80211/mac80211 built in?"
for s in "cfg80211" "mac80211" "ieee80211"; do
  n=$(strings -a /tmp/KERNEL | grep -c -- "$s")
  echo "  '$s' occurrences: $n"
done
