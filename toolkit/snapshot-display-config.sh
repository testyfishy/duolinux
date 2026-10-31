#!/bin/bash
# Snapshot the display/panel configuration that is working today, so a fresh
# install can reproduce it exactly.
set -euo pipefail
K=$HOME/.ssh/duo_key
H=root@192.168.86.33
REPO="/mnt/c/Users/HTPC-Aran/Documents/Default Project/duolinux/out/device-config"

echo "=== what KDE keeps for outputs"
ssh -i "$K" -o StrictHostKeyChecking=no "$H" '
  echo "--- kscreen dir:"; ls -l ~duo/.local/share/kscreen/ 2>/dev/null | head
  echo "--- kwin output config:"; ls -l ~duo/.config/kwinoutputconfig.json 2>/dev/null
  echo "--- plasma layout files:"; ls -l ~duo/.config/plasma-org.kde.plasma.desktop-appletsrc ~duo/.config/kwinrulesrc 2>/dev/null
'

echo
echo "=== pulling"
mkdir -p "$REPO/kscreen"
scp -q -i "$K" -o StrictHostKeyChecking=no -r "$H:/home/duo/.local/share/kscreen/." "$REPO/kscreen/" 2>/dev/null || true
scp -q -i "$K" -o StrictHostKeyChecking=no "$H:/home/duo/.config/kwinoutputconfig.json" "$REPO/kwinoutputconfig.json" 2>/dev/null || echo "  (no kwinoutputconfig.json)"
scp -q -i "$K" -o StrictHostKeyChecking=no "$H:/home/duo/.config/plasma-org.kde.plasma.desktop-appletsrc" "$REPO/plasma-org.kde.plasma.desktop-appletsrc"
scp -q -i "$K" -o StrictHostKeyChecking=no "$H:/home/duo/.config/kwinrulesrc" "$REPO/kwinrulesrc"
scp -q -i "$K" -o StrictHostKeyChecking=no "$H:/home/duo/.config/powerdevilrc" "$REPO/powerdevilrc"

echo
echo "=== captured"
ls -lR "$REPO/kscreen" | head -10
ls -l "$REPO"/kwinoutputconfig.json "$REPO"/plasma-org.kde.plasma.desktop-appletsrc "$REPO"/kwinrulesrc 2>/dev/null
