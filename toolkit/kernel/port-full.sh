#!/bin/bash
# Complete, ordered port: replay every patch of the series (package + device) on
# 7.2.0 using the same fuzz rules as the kernel build, then rebase the whole
# branch onto 7.2.11 so every patch is still a real 3-way merge.
#
# git apply is tried first (exact); `patch -F3` is the fallback that produced the
# working 7.2.0-nf kernel. 0208 fails both ways and stays dropped, as before.
set -uo pipefail
W=$HOME/rocknix-nf
P=$W/port/repo
K=$W/distribution
PKG=$K/projects/ROCKNIX/packages/linux/patches
DEV=$K/projects/ROCKNIX/devices/SM6115/patches/linux
LOG=$W/port-full.log
: > "$LOG"
exec >>"$LOG" 2>&1
cd "$P"

if ! git rev-parse -q --verify rk-7.2-full >/dev/null; then
    echo "=== replaying full series on 7.2.0"
    git checkout -q -B rk-7.2-full v7.2
    n=0; fuzzy=0; skipped=""
    for p in "$PKG"/*.patch "$DEV"/*.patch; do
        [ -f "$p" ] || continue
        b=$(basename "$p")
        if git apply --index --whitespace=nowarn "$p" 2>/dev/null; then
            git commit -q -m "rk: $b"; n=$((n+1)); continue
        fi
        if patch -p1 --dry-run -F3 < "$p" 2>&1 | grep -q FAILED; then
            skipped="$skipped $b"; continue
        fi
        fz=$(patch -p1 -F3 --no-backup-if-mismatch -s < "$p" 2>&1 | grep -c "with fuzz")
        git add -A
        if git diff --cached --quiet; then
            echo "NOCHANGE $b"; continue
        fi
        git commit -q -m "rk: $b" -m "applied with patch -F3${fz:+ (fuzz hunks: $fz)}"
        n=$((n+1)); fuzzy=$((fuzzy+1))
        echo "FUZZY $b (hunks applied with fuzz: $fz)"
    done
    echo "commits: $n, applied via patch -F3: $fuzzy"
    echo "skipped:$skipped"
    git log --oneline v7.2..rk-7.2-full | wc -l
fi

echo "=== rebasing full branch onto 7.2.11"
git checkout -q -B rk-7.2.11-full rk-7.2-full
GIT_EDITOR=true git rebase --onto v7.2.11-base v7.2 rk-7.2.11-full >/dev/null 2>&1
rc=$?
echo "rebase rc=$rc"
if [ "$rc" -ne 0 ]; then
    echo "=== stopped at:"; git log --oneline -1 REBASE_HEAD 2>/dev/null
    echo "=== unmerged:"; git diff --name-only --diff-filter=U
fi
