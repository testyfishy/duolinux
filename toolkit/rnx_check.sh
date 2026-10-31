#!/bin/bash
D="/mnt/c/path/to/duolinux/out/rnx-port/extract"
echo "=== binaries"
for b in pd-mapper rmtfs tqftpserv; do
  f="$D/usr/bin/$b"
  printf '%-10s %s\n' "$b" "$(file -b "$f" 2>/dev/null | cut -c1-90)"
  echo "   NEEDED: $(readelf -d "$f" 2>/dev/null | awk '/NEEDED/{print $5}' | tr -d '[]' | tr '\n' ' ')"
  echo "   interp: $(readelf -l "$f" 2>/dev/null | awk '/interpreter/{print $NF}' | tr -d ']')"
done

echo
echo "=== drop-ins"
for f in "$D/usr/lib/systemd/system/pd-mapper.service.d/rocknix.conf" \
         "$D/usr/lib/systemd/system/rmtfs.service.d/rocknix.conf" \
         "$D/usr/lib/systemd/system/rmtfs-dir.service" \
         "$D/usr/lib/systemd/system/rmtfs.service" \
         "$D/usr/lib/systemd/system/tqftpserv.service"; do
  echo "--- $f"
  cat "$f"
  echo
done

echo "=== retroid-duolite firmware files"
ls -l "$D/usr/lib/kernel-overlays/base/lib/firmware/ath10k/WCN3990/hw1.0/retroid-duolite/"
