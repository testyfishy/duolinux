#!/bin/bash
set -uo pipefail
cd "$HOME/rocknix-nf/port/repo" || exit 1
echo "=== build processes"
ps -eo pid,etime,cmd | grep -E "make|cc1" | grep -v grep | head -5 || echo "  none"
echo
echo "=== source state"
git checkout -- sound/soc/codecs/aw88166.c 2>/dev/null
if git diff --quiet -- sound/soc/codecs/aw88166.c; then
    echo "  aw88166.c: stock (patch reverted)"
else
    echo "  aw88166.c: STILL PATCHED"
fi
echo
echo "=== artefact from the killed build (ignore; will rebuild only if needed)"
ls -l "$HOME/rocknix-nf/KERNEL-7.2.11-nf" 2>/dev/null | awk '{print "  "$5" bytes  "$6" "$7" "$8}'
