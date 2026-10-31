#!/bin/bash
# Amend the 0032 commit with the corrected ordering, then replay the 47 commits
# after it on top. Only 0032 touches this file, so no conflicts are expected.
set -uo pipefail
cd "$HOME/rocknix-nf/port/repo"
C=$(git log --format='%H %s' rk-7.2.11-full | awk '/ 0032-power-supply-bq256xx-software-jeita/{print $1; exit}')
echo "0032 commit: $C"
git branch -f fix0032 "$C"
git checkout -q fix0032
python3 "/mnt/c/Users/user/Documents/Default Project/duolinux/toolkit/kernel/fix-0032-order.py" || exit 1
git add drivers/power/supply/bq256xx_charger.c
git commit -q --amend --no-edit
NEW=$(git rev-parse HEAD)
echo "amended: $NEW"
git checkout -q rk-7.2.11-full
GIT_EDITOR=true git rebase --onto "$NEW" "$C" rk-7.2.11-full > /tmp/rb2.log 2>&1
echo "rebase rc=$? / $(tail -1 /tmp/rb2.log)"
git branch -D fix0032 >/dev/null 2>&1
echo "commits: $(git rev-list --count v7.2.11-base..rk-7.2.11-full)"
