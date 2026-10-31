#!/bin/bash
# Inspect the Debian rootfs inside out/duolinux-duol.img (partition 2)
cd "/mnt/c/Users/HTPC-Aran/Documents/Default Project/duolinux/out" || exit 1
D="duolinux-duol.img?offset=537919488"

dump() {
  echo "===== $1"
  rm -f /tmp/o.txt
  debugfs -R "dump $1 /tmp/o.txt" "$D" >/dev/null 2>&1
  if [ -f /tmp/o.txt ]; then cat /tmp/o.txt; else echo "(missing)"; fi
  rm -f /tmp/o.txt
}

lsdir() {
  echo "===== ls $1"
  debugfs -R "ls -l $1" "$D" 2>/dev/null | awk '{print $NF}' | tail -n +2
}

lsdir /etc/sway
dump /etc/sway/config
lsdir /etc/NetworkManager/system-connections
lsdir /lib/modules
lsdir /etc/systemd/system/multi-user.target.wants
lsdir /lib/firmware/ath10k
dump /etc/duo/duo.conf
