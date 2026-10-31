#!/bin/bash
# Prove the 7.2.11 port is faithful.
#
# 1. range-diff: does each patch still say what it said on 7.2.0?
# 2. commutation: stable's changes and the series' changes must compose the same
#    way in either order. Compared on CONTENT only (index lines and hunk
#    headers are positional and would differ even when the merge is perfect).
# 3. sanity: every file the series touches still exists and has no conflict
#    markers left behind.
set -uo pipefail
cd "$HOME/rocknix-nf/port/repo"
BR=rk-7.2.11-full
BASE=rk-7.2-full

echo "=== commits: $(git rev-list --count v7.2.11-base..$BR)"
echo
echo "=== range-diff"
git range-diff v7.2..$BASE v7.2.11-base..$BR > /tmp/rd.txt 2>&1
echo "  patches reported as changed: $(grep -cE '^[0-9]+: [0-9a-f]+ [!=]' /tmp/rd.txt)"
echo "  patches identical ( = ):      $(grep -cE '^[0-9]+: [0-9a-f]+ = ' /tmp/rd.txt)"
grep -E '^[0-9]+: [0-9a-f]+ ! ' /tmp/rd.txt | sed 's/^/  /' | cut -c1-100

echo
echo "=== commutation (content only)"
F=$(git diff --name-only v7.2 $BASE)
ok=0; bad=""
# Only the actual changed lines: context lines differ legitimately once the
# series' own code sits next to stable's hunk.
norm() { grep -E '^[+-][^+-]' ; }
for f in $F; do
    a=$(git diff v7.2 v7.2.11-base -- "$f" | norm)
    b=$(git diff $BASE $BR -- "$f" | norm)
    if [ "$a" = "$b" ]; then ok=$((ok+1)); else bad="$bad $f"; fi
done
echo "  files touched: $(echo "$F" | wc -l), commuting: $ok, differing: $(echo $bad | wc -w)"
[ -n "$bad" ] && for f in $bad; do echo "  DIFF: $f"; done

echo
echo "=== conflict markers anywhere in touched files?"
git grep -lE '^(<<<<<<<|>>>>>>>) ' -- $F 2>/dev/null | head -5 || echo "  none"

echo
echo "=== net diff vs 7.2.11 base"
git diff --stat v7.2.11-base $BR | tail -1
