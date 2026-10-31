#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
command -v unsquashfs >/dev/null || { apt-get update -qq; apt-get install -y -qq squashfs-tools rsync >/dev/null; }

S=/mnt/rnx/SYSTEM
DEST="/mnt/c/path/to/duolinux/out/rnx-root"
mkdir -p "$DEST"

echo "=== interesting paths in their system:"
unsquashfs -ll "$S" 2>/dev/null | awk '{print $NF}' | grep -E \
  '(^/usr/(s)?bin/(rmtfs|pd-mapper|tqftpserv|qrtr-.*)$)|(/systemd/system/[^/]*(rmtfs|pd-mapper|tqftpserv|qrtr|wpa|wifi|bluetooth)[^/]*$)|(/firmware/qcom/sm6125/)|(/firmware/ath10k/WCN3990/)|(udev/rules.d/.*)|(rocknix.*\.sh$)|(/etc/(wpa_supplicant|NetworkManager))' \
  | sort -u | head -80
