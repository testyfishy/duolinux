#!/bin/bash
set -u
S=/mnt/rnx/SYSTEM
OUT="/mnt/c/Users/user/Documents/Default Project/duolinux/out/rnx-port/duo"
mkdir -p "$OUT"

CANDIDATES="
usr/lib/systemd/system/duolite-bottom-screen.service
usr/lib/systemd/system/sway-touch.service
usr/lib/systemd/system/essway.service
usr/lib/autostart/common/111-sway-init
usr/bin/sway-touch.sh
usr/bin/sway.sh
usr/lib/sway/sway-config
usr/share/sway/config
etc/profile.d/050-sway.conf
"

for f in $CANDIDATES; do
  name=$(echo "$f" | tr '/' '_')
  if unsquashfs -cat "$S" "$f" > "$OUT/$name" 2>/dev/null; then
    if [ -s "$OUT/$name" ]; then
      echo "===== $f"
      cat "$OUT/$name"
      echo
    else
      rm -f "$OUT/$name"
    fi
  fi
done
