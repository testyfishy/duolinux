#!/bin/bash
set -e
S=/mnt/rnx/SYSTEM
DEST="/mnt/c/Users/HTPC-Aran/Documents/Default Project/duolinux/out/rnx-port"

echo "=== libqrtr and friends"
unsquashfs -ll "$S" 2>/dev/null | awk '{print $NF}' | grep -E 'libqrtr[^/]*$' | sort -u

echo "=== which rmtfs variant is enabled (symlinks in their image)"
for p in etc/systemd/system/multi-user.target.wants etc/systemd/system/network.target.wants etc/systemd/system/sysinit.target.wants; do
  unsquashfs -ll "$S" 2>/dev/null | grep "$p" | grep -Ei 'rmtfs|pd-mapper|tqftpserv|qrtr' || true
done

echo "=== rmtfs man page / help text"
unsquashfs -ll "$S" 2>/dev/null | awk '{print $NF}' | grep -Ei 'rmtfs\.(1|8)|rmtfs.*md$' | head
unsquashfs -ll "$S" 2>/dev/null | awk '{print $NF}' | grep -E 'usr/share/man/man1/rmtfs' | head

echo "=== extracting libqrtr + man page"
LIST=$(unsquashfs -ll "$S" 2>/dev/null | awk '{print $NF}' | grep -E '(libqrtr[^/]*$)|(share/man/man1/rmtfs[^/]*$)' | sed 's|^squashfs-root/||')
echo "$LIST"
# shellcheck disable=SC2086
unsquashfs -d "$DEST/extract" "$S" $LIST >/dev/null 2>&1 || true
find "$DEST/extract" -name 'libqrtr*' -o -name 'rmtfs.1*' | head

echo "=== if there is a man page, show it"
MP=$(find "$DEST/extract" -name 'rmtfs.1*' | head -1)
[ -n "$MP" ] && (zcat "$MP" 2>/dev/null || cat "$MP") | sed 's/\x1b\[[0-9;]*m//g' | head -60
