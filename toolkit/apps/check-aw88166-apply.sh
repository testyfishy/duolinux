#!/bin/bash
# Do the ROCKNIX aw88166 fixes apply to our 7.2.11 tree, and what do they change?
set -uo pipefail
K=$HOME/rocknix-nf/port/repo
D=$HOME/rocknix-nf/distribution/projects/ROCKNIX/devices

cd "$K" || exit 1
for f in "$D"/SM4450/patches/linux/00{31,32,33,34}-*aw88166*.patch; do
    [ -f "$f" ] || continue
    printf '%-70s ' "$(basename "$f")"
    if git apply --check "$f" >/dev/null 2>&1; then echo "APPLIES"; else echo "conflicts"; fi
done

echo
echo "=== 0034 full diff, files touched"
P=$(ls "$D"/SM4450/patches/linux/0034-*aw88166*make-volume*.patch | head -1)
grep -E '^\+\+\+ b/|^--- a/' "$P" | sed 's/^/  /'
echo
echo "=== 0034 body (first 80 lines of the diff)"
sed -n '1,80p' "$P" | sed 's/^/  /'
