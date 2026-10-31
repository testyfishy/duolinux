#!/bin/bash
# Pull the device's per-user config that must be reproducible into the repo.
set -euo pipefail
K=$HOME/.ssh/duo_key
REPO="/mnt/c/Users/user/Documents/Default Project/duolinux/out/device-config"
scp -q -i "$K" -o StrictHostKeyChecking=no \
    root@192.168.1.33:/home/duo/.config/kwinrulesrc "$REPO/kwinrulesrc"
echo "saved kwinrulesrc"
scp -q -i "$K" -o StrictHostKeyChecking=no \
    root@192.168.1.33:/home/duo/.local/share/applications/duo-tailscale.desktop \
    "$REPO/duo-tailscale.desktop"
echo "saved duo-tailscale.desktop"
ls -l "$REPO/kwinrulesrc" "$REPO/duo-tailscale.desktop"
