#!/bin/bash
set -uo pipefail
cd "$HOME/rocknix-nf/port/repo"
echo "authmap lines: $(wc -l < /tmp/authmap.txt)"
echo "first 2 lines:"; head -2 /tmp/authmap.txt
echo
h=$(git rev-list rk-7.2.11-base..rk-7.2.11-full | head -1)
echo "first commit: $h"
echo "grep result:"
grep -F "$h|" /tmp/authmap.txt || echo "  NO MATCH"
echo
echo "clist first: $(head -1 /tmp/clist.txt)"
echo "last: $(tail -1 /tmp/clist.txt)"
echo
echo "does the range still have 79 commits? $(git rev-list --count rk-7.2.11-base..rk-7.2.11-full)"
echo "current branch: $(git rev-parse --abbrev-ref HEAD)"
echo "refs/original: $(ls .git/refs/original 2>/dev/null || echo none)"
