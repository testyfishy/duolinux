#!/bin/bash
cd "/mnt/c/path/to/duolinux/out" || exit 1
D="duolinux-duol.img?offset=537919488"

dump() {
  echo "===== $1"
  rm -f /tmp/o.txt
  debugfs -R "dump $1 /tmp/o.txt" "$D" >/dev/null 2>&1
  if [ -f /tmp/o.txt ]; then cat /tmp/o.txt; else echo "(missing)"; fi
  rm -f /tmp/o.txt
}

lsgrep() {
  echo "===== ls $1 | grep $2"
  debugfs -R "ls /$1" "$D" 2>/dev/null | tr ' ' '\n' | grep -i -E "$2" | sort -u
}

lsgrep lib/modules/7.2.0/kernel/drivers/net/wireless "ath|wcn|cfg80211|mac80211"
lsgrep lib/modules/7.2.0/kernel/drivers/net/wireless/ath "."
lsgrep lib/modules/7.2.0/kernel/drivers/gpu/drm/bridge "anx|ti|ite"
lsgrep lib/modules/7.2.0/kernel/drivers/gpu/drm/panel "."
lsgrep lib/modules/7.2.0/kernel/drivers/bluetooth "."
echo "===== /usr/local/bin contents (duo-inputd):"
dump /usr/local/bin/duo-inputd
