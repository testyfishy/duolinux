#!/bin/bash
set -uo pipefail
P=$HOME/rocknix-nf/distribution/projects/ROCKNIX/devices/SM6115/patches/linux
cd "$HOME/rocknix-nf/port/repo"

echo "=== authors declared in the original series"
grep -h -E "^From: |^Author: " "$P"/*.patch 2>/dev/null | sed 's/^From: //; s/^Author: //' | sort | uniq -c | sort -rn

echo
echo "=== which original patches have NO author line"
for f in "$P"/*.patch; do
    grep -qE "^From: |^Author: " "$f" || basename "$f"
done | head -50

echo
echo "=== authors now in the published branch"
git log --format='%an <%ae>' v7.2.11-base..rk-7.2.11-pub | sort | uniq -c | sort -rn
