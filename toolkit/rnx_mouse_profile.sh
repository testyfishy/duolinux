#!/bin/bash
set -u
S=/mnt/rnx/SYSTEM
OUT="/mnt/c/Users/HTPC-Aran/Documents/Default Project/duolinux/out/rnx-port/profiles"
mkdir -p "$OUT"

for f in mouse_keyboard_wasd.yaml default.yaml; do
    unsquashfs -cat "$S" "usr/share/inputplumber/profiles/$f" > "$OUT/$f" 2>/dev/null
    echo "===== $f ($(wc -l < "$OUT/$f") lines)"
    cat "$OUT/$f"
    echo
done
