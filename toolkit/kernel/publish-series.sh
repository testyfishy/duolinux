#!/bin/bash
# Published series with original authorship, mapped by position.
#   format-patch 0001..0079  <->  patch files in replay order
# No subject matching, no filter-branch. Verifies the rebuilt branch is
# byte-identical to the working one before anything is published.
set -euo pipefail
W=$HOME/rocknix-nf
DEV=$W/distribution/projects/ROCKNIX/devices/SM6115/patches/linux
PKG=$W/distribution/projects/ROCKNIX/packages/linux/patches
cd "$W/port/repo"

SRC=rk-7.2.11-full
OUT=/tmp/pub2
rm -rf "$OUT"; mkdir -p "$OUT"
git format-patch -q v7.2.11-base.."$SRC" -o "$OUT" >/dev/null

# replay order
ls "$PKG"/*.patch > /tmp/plist.txt 2>/dev/null || true
ls "$DEV"/*.patch >> /tmp/plist.txt

python3 - "$OUT" <<'PY'
import glob, io, os, re, sys
out = sys.argv[1]
patches = [l.strip() for l in open("/tmp/plist.txt") if l.strip()]
gen = sorted(glob.glob(os.path.join(out, "*.patch")))
if len(gen) != len(patches):
    sys.exit(f"count mismatch {len(gen)} vs {len(patches)}")

restored = 0
for g, p in zip(gen, patches):
    src = io.open(p, encoding="utf-8", errors="ignore").read()
    head = src[:4000]
    m = re.search(r"^From: (.+)$", head, re.M) or re.search(r"^Author: (.+)$", head, re.M)
    d = re.search(r"^Date: (.+)$", head, re.M)
    if not m:
        continue
    text = io.open(g, encoding="utf-8").read()
    text = re.sub(r"^From: .+$", "From: " + m.group(1).strip(), text, count=1, flags=re.M)
    if d:
        text = re.sub(r"^Date: .+$", "Date: " + d.group(1).strip(), text, count=1, flags=re.M)
    # strip the [PATCH n/m] counter so the subject is clean when published
    text = re.sub(r"^Subject: \[PATCH[^\]]*\] ", "Subject: ", text, count=1, flags=re.M)
    io.open(g, "w", encoding="utf-8", newline="\n").write(text)
    restored += 1
print(f"authors restored: {restored}/{len(gen)}")
PY

echo "=== rebuilding to verify"
git checkout -q -B pub-check v7.2.11-base
git am -q "$OUT"/*.patch
if git diff --quiet "$SRC" pub-check; then echo "  trees identical"; else echo "  TREES DIFFER"; exit 1; fi
echo "  commits: $(git rev-list --count v7.2.11-base..pub-check)"
git log --format='%an <%ae>' v7.2.11-base..pub-check | sort | uniq -c | sort -rn
