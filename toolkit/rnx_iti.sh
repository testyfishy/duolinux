#!/bin/bash
set -u
S=/mnt/rnx/SYSTEM
OUT="/mnt/c/Users/HTPC-Aran/Documents/Default Project/duolinux/out/rnx-port/internal"
mkdir -p "$OUT"
unsquashfs -cat "$S" usr/bin/installtointernal > "$OUT/installtointernal" 2>/dev/null
echo "=== installtointernal ($(wc -l < "$OUT/installtointernal") lines)"
cat "$OUT/installtointernal"
