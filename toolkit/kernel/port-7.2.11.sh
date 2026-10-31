#!/bin/bash
# Port the ROCKNIX SM6115 series from 7.2.0 to 7.2.11 with real git 3-way merges.
#
# Method (advisor): build a branch on v7.2 with one commit per patch, then
# rebase --onto v7.2.11. Each commit is replayed as a 3-way merge against the
# new base, so context drift resolves itself and genuine API changes surface as
# conflicts instead of silently applying.
#
# Both tarballs are already downloaded, so this runs offline:
#   src/linux-7.2.tar.xz       (base the series was generated against)
#   linux-7.2.11.tar.xz        (target)
set -uo pipefail
W=$HOME/rocknix-nf
P=$W/port
K=$W/distribution
PKG=$K/projects/ROCKNIX/packages/linux/patches
DEV=$K/projects/ROCKNIX/devices/SM6115/patches/linux
LOG=$W/port.log
: > "$LOG"
exec >>"$LOG" 2>&1
cd "$W"

if [ ! -d "$P/repo/.git" ]; then
    echo "=== unpacking"
    rm -rf "$P"; mkdir -p "$P/x72" "$P/x7211"
    tar xf src/linux-7.2.tar.xz -C "$P/x72" --strip-components=1
    tar xf linux-7.2.11.tar.xz -C "$P/x7211" --strip-components=1
    mv "$P/x72" "$P/repo"
    cd "$P/repo"
    git init -q -b main
    git config user.name "duolinux kernel port"
    git config user.email "port@localhost"
    git config rerere.enabled true
    git config merge.conflictStyle zdiff3
    git add -A
    git commit -q -m "Linux 7.2.0 (vanilla tarball)"
    git tag v7.2
    echo "=== applying series on 7.2.0"
    git checkout -q -b rk-7.2
    n=0; f=0
    for p in "$PKG"/*.patch "$DEV"/*.patch; do
        [ -f "$p" ] || continue
        b=$(basename "$p")
        if git apply --index --whitespace=nowarn "$p" 2>/dev/null; then
            git commit -q -m "rk: $b"
            n=$((n+1))
        else
            echo "APPLY-FAIL-ON-7.2 $b"
            f=$((f+1))
        fi
    done
    echo "applied on 7.2.0: $n commits, failed: $f"
fi

cd "$P/repo"
if ! git rev-parse -q --verify v7.2.11-base >/dev/null; then
    echo "=== importing 7.2.11 tree as base"
    git checkout -q --orphan v7.2.11-base
    git rm -rqf . 2>/dev/null
    find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
    cp -a "$P/x7211/." .
    git add -A
    git commit -q -m "Linux 7.2.11 (vanilla tarball)"
fi

echo "=== rebase onto 7.2.11"
git checkout -q -B rk-7.2.11 rk-7.2
GIT_EDITOR=true git rebase --onto v7.2.11-base v7.2 rk-7.2.11
rc=$?
echo "rebase rc=$rc"
if [ "$rc" -ne 0 ]; then
    echo "=== stopped at:"
    git log --oneline -1 REBASE_HEAD 2>/dev/null
    echo "=== unmerged:"
    git diff --name-only --diff-filter=U
    echo "=== rebase state kept (resolve, then git rebase --continue)"
else
    echo "=== all commits replayed"
    git log --oneline v7.2.11-base..rk-7.2.11 | wc -l
fi
