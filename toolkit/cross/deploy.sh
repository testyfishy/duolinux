#!/bin/bash
# Push a cross-built binary to the handheld and restart its service.
#
# Usage (from Windows PowerShell):
#   wsl -d Ubuntu-26.04 bash "<repo>/toolkit/cross/deploy.sh"
#
# Requires out/duo_ssh_key (git-ignored).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOST="${DUO_HOST:-root@192.168.86.33}"
KEY="$REPO/out/duo_ssh_key"
BIN="$REPO/out/build/inputplumber"

[ -f "$BIN" ] || { echo "build first: toolkit/cross/build-inputplumber.sh" >&2; exit 1; }
chmod 600 "$KEY" 2>/dev/null || true

ssh_opts=(-i "$(wslpath -u "$KEY" 2>/dev/null || echo "$KEY")"
           -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
           -o ConnectTimeout=10 -o BatchMode=yes)

scp "${ssh_opts[@]}" "$BIN" "$HOST:/usr/local/bin/inputplumber.new"
ssh "${ssh_opts[@]}" "$HOST" '
    set -e
    [ -f /usr/local/bin/inputplumber ] && cp -f /usr/local/bin/inputplumber /usr/local/bin/inputplumber.bak
    chmod 755 /usr/local/bin/inputplumber.new
    mv -f /usr/local/bin/inputplumber.new /usr/local/bin/inputplumber
    systemctl restart inputplumber
    sleep 5
    systemctl is-active inputplumber
    readlink -f /proc/$(pgrep -x inputplumber | head -1)/exe
'
echo "rolled back? cp /usr/local/bin/inputplumber.bak /usr/local/bin/inputplumber && systemctl restart inputplumber"
