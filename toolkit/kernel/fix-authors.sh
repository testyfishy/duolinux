#!/bin/bash
# Restore original authorship on the ported series, deterministically.
#
# The branch was built one commit per patch, in the same order as the patch
# files, so commit i <-> patch i. No text matching, no format-patch round trip.
# Patches with no author line keep the port identity and are listed separately.
set -euo pipefail
W=$HOME/rocknix-nf
DEV=$W/distribution/projects/ROCKNIX/devices/SM6115/patches/linux
PKG=$W/distribution/projects/ROCKNIX/packages/linux/patches
cd "$W/port/repo"

SRC=rk-7.2.11-full
TAG=pre-author-fix
git tag -f "$TAG" "$SRC" >/dev/null

# ordered patch list exactly as the branch was replayed
ls "$PKG"/*.patch > /tmp/plist.txt 2>/dev/null || true
ls "$DEV"/*.patch >> /tmp/plist.txt

# ordered commit list
git rev-list --reverse v7.2.11-base.."$SRC" > /tmp/clist.txt

echo "patches: $(wc -l < /tmp/plist.txt), commits: $(wc -l < /tmp/clist.txt)"

python3 - <<'PY'
import re, subprocess
patches = [l.strip() for l in open("/tmp/plist.txt") if l.strip()]
commits = [l.strip() for l in open("/tmp/clist.txt") if l.strip()]
if len(patches) != len(commits):
    raise SystemExit(f"count mismatch: {len(patches)} patches vs {len(commits)} commits")
out = []
for c, p in zip(commits, patches):
    head = open(p, encoding="utf-8", errors="ignore").read(4000)
    m = re.search(r"^From: (.+)$", head, re.M) or re.search(r"^Author: (.+)$", head, re.M)
    d = re.search(r"^Date: (.+)$", head, re.M)
    if not m:
        continue
    a = m.group(1).strip()
    em = re.search(r"^(.*?)\s*<(.+)>$", a)
    name = em.group(1).strip() if em else a
    email = em.group(2).strip() if em else ""
    date = d.group(1).strip() if d else ""
    out.append(f"{c}|{name}|{email}|{date}")
open("/tmp/authmap.txt", "w").write("\n".join(out) + "\n")
print(f"mapped authors: {len(out)}/{len(patches)}")
PY

git filter-branch -f --env-filter '
line=$(grep -F "$GIT_COMMIT|" /tmp/authmap.txt | head -1 || true)
if [ -n "$line" ]; then
  n=$(printf "%s" "$line" | cut -d"|" -f2)
  e=$(printf "%s" "$line" | cut -d"|" -f3)
  d=$(printf "%s" "$line" | cut -d"|" -f4)
  export GIT_AUTHOR_NAME="$n"
  export GIT_AUTHOR_EMAIL="$e"
  if [ -n "$d" ]; then export GIT_AUTHOR_DATE="$d"; fi
fi
exit 0
' v7.2.11-base.."$SRC" > /tmp/fb.log 2>&1 || { tail -5 /tmp/fb.log; exit 1; }

echo "=== tree check"
if git diff --quiet "$TAG" "$SRC"; then echo "  trees identical"; else echo "  TREES DIFFER"; exit 1; fi
echo "=== authors"
git log --format='%an <%ae>' v7.2.11-base.."$SRC" | sort | uniq -c | sort -rn
git tag -d "$TAG" >/dev/null
rm -rf .git/refs/original
