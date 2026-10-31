#!/bin/bash
cd "/mnt/c/path/to/duolinux/out" || exit 1
D="duolinux-duol.img?offset=537919488"

echo "===== looking for the modem/Wi-Fi userspace helpers in dpkg status:"
rm -f /tmp/status.txt
debugfs -R "dump /var/lib/dpkg/status /tmp/status.txt" "$D" >/dev/null 2>&1
if [ -f /tmp/status.txt ]; then
  for p in rmtfs pd-mapper tqftpserv qrtr-tools libqrtr-glib0 libqmi-glib5 libmbim-glib4 modemmanager firmware-qcom-soc firmware-atheros iw wireless-tools; do
    printf "%-22s " "$p"
    grep -q "^Package: $p$" /tmp/status.txt && echo INSTALLED || echo missing
  done
  echo "===== modem firmware files:"
  for f in /lib/firmware/qcom/sm6125/modem.mbn /lib/firmware/qcom/sm6125/mba.mbn /lib/firmware/qcom/sm6125/modem_nm.mbn; do
    printf "%-46s " "$f"
    debugfs -R "stat $f" "$D" 2>/dev/null | grep -q Inode && echo present || echo MISSING
  done
  echo "===== what is in /lib/firmware/qcom/sm6125:"
  debugfs -R "ls /lib/firmware/qcom/sm6125" "$D" 2>/dev/null
else
  echo "(no dpkg status dump)"
fi
rm -f /tmp/status.txt
