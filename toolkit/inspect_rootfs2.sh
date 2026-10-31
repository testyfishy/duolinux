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

dump /etc/passwd
dump /etc/ssh/sshd_config.d/10-duo.conf
dump /etc/systemd/system/duo-firstboot.service
dump /etc/systemd/system/duo-inputd.service
echo "===== /usr/local/bin"
debugfs -R "ls /usr/local/bin" "$D" 2>/dev/null | awk '{print $NF}' | tail -n +2
