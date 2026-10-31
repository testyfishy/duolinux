#!/bin/bash
set -e
S=/mnt/rnx/SYSTEM
DEST="/mnt/c/path/to/duolinux/out/rnx-port"
rm -rf "$DEST"; mkdir -p "$DEST"

echo "=== locating binaries"
unsquashfs -ll "$S" 2>/dev/null | awk '{print $NF}' | grep -E '/(pd-mapper|rmtfs|tqftpserv|qrtr-ns)$' | sort -u

echo "=== extracting binaries, units, drop-ins, firmware, udev rules"
LIST=$(unsquashfs -ll "$S" 2>/dev/null | awk '{print $NF}' | grep -E \
  '(/(pd-mapper|rmtfs|tqftpserv|qrtr-ns)$)|(systemd/system/(pd-mapper|rmtfs|rmtfs-dir|tqftpserv)[^/]*$)|(systemd/system/(pd-mapper|rmtfs|rmtfs-dir|tqftpserv)[^/]*/.*$)|(firmware/ath10k/WCN3990/hw1.0/retroid-duolite/.*$)|(udev/rules.d/.*(joystick|evdev|input|rocknix|retroid).*$)' \
  | sed 's|^squashfs-root/||')

echo "$LIST" | head -40
# shellcheck disable=SC2086
unsquashfs -d "$DEST/extract" "$S" $LIST >/dev/null 2>&1 || true

echo "=== extracted tree"
find "$DEST" -type f | sed "s|$DEST/||" | sort | head -60

echo "=== unit contents"
for u in pd-mapper rmtfs rmtfs-dir tqftpserv; do
  f=$(find "$DEST" -path "*systemd/system/$u.service" -type f | head -1)
  [ -n "$f" ] && { echo "--- $u.service"; cat "$f"; }
  for d in $(find "$DEST" -path "*$u.service.d*" -type f 2>/dev/null); do
    echo "--- drop-in $d"; cat "$d"
  done
done
