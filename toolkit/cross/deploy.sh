#!/bin/bash
# Push a cross-built binary to the handheld and restart its service.
#
# Usage (from Windows PowerShell):
#   wsl -d Ubuntu-26.04 bash "<repo>/toolkit/cross/deploy.sh"
#
# Requires out/duo_ssh_key (git-ignored). The key is copied to ~/.ssh because
# /mnt/c does not carry POSIX permissions, and ssh refuses an open key.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOST="${DUO_HOST:-root@192.168.1.33}"
BIN="$REPO/out/build/inputplumber"
KEY="$HOME/.ssh/duo_ssh_key"

[ -f "$BIN" ] || { echo "build first: toolkit/cross/build-inputplumber.sh" >&2; exit 1; }
[ -f "$REPO/out/duo_ssh_key" ] || { echo "missing out/duo_ssh_key" >&2; exit 1; }

mkdir -p "$HOME/.ssh"
tr -d '\r' < "$REPO/out/duo_ssh_key" > "$KEY"
chmod 600 "$KEY"

ssh_opts=(-i "$KEY"
          -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
          -o ConnectTimeout=10 -o BatchMode=yes)

scp "${ssh_opts[@]}" "$BIN" "$HOST:/usr/local/bin/inputplumber.new"
ssh "${ssh_opts[@]}" "$HOST" '
    set -e
    [ -f /usr/local/bin/inputplumber ] && cp -f /usr/local/bin/inputplumber /usr/local/bin/inputplumber.bak
    chmod 755 /usr/local/bin/inputplumber.new
    mv -f /usr/local/bin/inputplumber.new /usr/local/bin/inputplumber
    systemctl restart inputplumber
    sleep 4
    # duo-mouse-apply loads the stick-to-mouse profile into the daemon; a
    # restart drops it, so re-apply it explicitly (PartOf= also covers this).
    systemctl restart duo-mouse 2>/dev/null || true
    sleep 2
    echo "service: $(systemctl is-active inputplumber)"
    echo "mouse:   $(systemctl is-active duo-mouse) flag=$(ls /run/user/1000/duo-mouse.on 2>/dev/null || echo missing)"
    echo "binary:  $(readlink -f /proc/$(pgrep -x inputplumber | head -1)/exe)"
'
echo "rollback: cp /usr/local/bin/inputplumber.bak /usr/local/bin/inputplumber && systemctl restart inputplumber"
