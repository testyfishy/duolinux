#!/bin/bash
cd "/mnt/c/Users/HTPC-Aran/Documents/Default Project/duolinux/out" || exit 1
D="duolinux-duol.img?offset=537919488"

echo "===== ath10k modules:"
debugfs -R "ls /lib/modules/7.2.0/kernel/drivers/net/wireless/ath/ath10k" "$D" 2>/dev/null

echo "===== any module mentioning snoc/wcn/cfg80211/mac80211 in its filename:"
for d in /lib/modules/7.2.0/kernel/drivers/net/wireless /lib/modules/7.2.0/kernel/net; do
  echo "-- $d"
  debugfs -R "ls $d" "$D" 2>/dev/null
done

echo "===== modules.dep lines for wifi:"
rm -f /tmp/mdep.txt
debugfs -R "dump /lib/modules/7.2.0/modules.dep /tmp/mdep.txt" "$D" >/dev/null 2>&1
grep -i -E "ath10k|cfg80211|mac80211|wcn" /tmp/mdep.txt 2>/dev/null | head -20
rm -f /tmp/mdep.txt

echo "===== extract DTB from the boot partition and look for radios/panels:"
cd "/mnt/c/Users/HTPC-Aran/Documents/Default Project/duolinux/out"
mcopy -o -n -i "duolinux-duol.img@@1048576" ::/dtbs/qcom/sm6125-retroid-pocket-duo-lite.dtb /tmp/duo.dtb 2>/dev/null
ls -l /tmp/duo.dtb
which dtc || echo "no dtc"
if command -v dtc >/dev/null 2>&1; then
  dtc -I dtb -O dts /tmp/duo.dtb -o /tmp/duo.dts 2>/dev/null
  echo "-- wifi/bluetooth nodes:"
  grep -n -i -E "wifi|wcn|wlan|bluetooth|bt_qca" /tmp/duo.dts | head -20
  echo "-- display/bridge nodes:"
  grep -n -i -E "anx|bridge|dsi|panel|display" /tmp/duo.dts | head -40
else
  echo "-- strings fallback:"
  strings /tmp/duo.dtb | grep -i -E "wcn|wifi|anx|panel|dsi" | sort -u | head -30
fi
