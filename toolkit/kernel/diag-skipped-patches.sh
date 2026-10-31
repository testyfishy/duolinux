#!/bin/bash
# A) Apply the 4 patches that git apply rejected, using `patch -F3` at their
#    proper position (this is what produced the working 7.2.0-nf kernel).
# B) Contact-sheet: do they apply at the ported branch head?
set -uo pipefail
cd "$HOME/rocknix-nf/port/repo"
P=$HOME/rocknix-nf/distribution/projects/ROCKNIX/devices/SM6115/patches/linux

echo "=== A: proper predecessors (branch rk-7.2 = 7.2.0 series)"
for n in 0023 0024 0208 0210; do
    pred=$(git log --reverse --format='%s|%H' rk-7.2 | awk -F'|' -v n="$n" '$1 ~ ("rk: " n) {print; exit}')
    last=$(git log --reverse --format='%s|%H' rk-7.2 | awk -F'|' -v n="$n" '$1 < ("rk: " n ".patch") {c=$0} END {print c}')
    echo "$n predecessor: $last"
done

echo
echo "=== B: dry-run at ported head (rk-7.2.11)"
git checkout -q rk-7.2.11
for n in 0023 0024 0208 0210; do
    f=$(ls "$P"/$n-*.patch)
    echo "--- $(basename "$f")"
    if git apply --check "$f" 2>/dev/null; then
        echo "  git apply: clean"
    else
        out=$(patch -p1 --dry-run -F3 < "$f" 2>&1)
        if echo "$out" | grep -q "FAILED"; then
            echo "  fails: $(echo "$out" | grep -c FAILED) hunks"
        else
            echo "  patch -F3: ok ($(echo "$out" | grep -c 'with fuzz') fuzz hunks)"
        fi
    fi
done
