#!/bin/bash
set -u
S=/mnt/rnx/SYSTEM
echo "=== lowerdeck / inputplumber / OSK binaries in their system"
unsquashfs -ll "$S" 2>/dev/null | awk '{print $NF}' | grep -iE 'lowerdeck|inputplumber|wvkbd|squeekboard|onboard|matchbox' | head -20

echo "=== sway config defaults (kiosk/desktop) that reference them"
unsquashfs -ll "$S" 2>/dev/null | awk '{print $NF}' | grep -E 'usr/share/sway/(config|config\.)' | head -10

echo "=== kernel-overlay dtb files?"
unsquashfs -ll "$S" 2>/dev/null | awk '{print $NF}' | grep -iE 'kernel-overlays/.*/dtb|kernel-overlays/.*\.dtbo' | head -10
