#!/bin/bash
set -e
cd "/mnt/c/path/to/duolinux" || exit 1

echo "=== restoring arm64 binaries from the cached .debs (undo CRLF damage)"
for d in /tmp/duodebs/*.deb; do
  echo "  $(basename "$d")"
  dpkg-deb -x "$d" out/overlay
done

echo "=== normalising text files only (binaries are skipped)"
python3 toolkit/fix_overlay.py out/overlay

echo "=== binary sanity"
python3 toolkit/check_bins.py \
  out/overlay/usr/bin/tqftpserv \
  out/overlay/usr/bin/rmtfs \
  out/overlay/usr/bin/qrtr-ns \
  out/overlay/usr/bin/qrtr-lookup \
  out/overlay/usr/bin/qrtr-cfg
