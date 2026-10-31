#!/bin/bash
# Copy the authored series into the repo and generate SERIES with provenance.
set -euo pipefail
cd "$HOME/rocknix-nf/port/repo"
REPO="/mnt/c/Users/user/Documents/Default Project/duolinux/kernel/patches/7.2.11"
rm -rf "$REPO"; mkdir -p "$REPO"
cp /tmp/pub2/*.patch "$REPO"/

{
    echo "# SM6115 / Retroid Pocket Duo Lite series, rebased onto Linux 7.2.11"
    echo "#"
    echo "# base:   vanilla 7.2.11 (kernel.org tarball)"
    echo "# source: ROCKNIX projects/ROCKNIX/devices/SM6115/patches/linux"
    echo "#         snapshot 2026-10-29; the series was generated against 7.2.0"
    echo "# count:  79"
    echo "#"
    echo "# 'author' is taken from the original patch header. Where it is empty the"
    echo "# source patch carries no From:/Author: line at all; those commits are"
    echo "# attributed to the port identity and MUST NOT be sent upstream as-is."
    echo "#"
    printf '%-5s %-6s %s\n' "#" "status" "subject / author"
    i=0
    for p in "$REPO"/*.patch; do
        i=$((i+1))
        subj=$(sed -n 's/^Subject: //p' "$p" | head -1)
        auth=$(sed -n 's/^From: //p' "$p" | head -1)
        case "$subj" in
            0032*) st="FIXED" ;;
            *)     st="asis" ;;
        esac
        printf '%-5s %-6s %s\n' "$(printf '%04d' "$i")" "$st" "$subj"
        printf '%-5s %-6s   %s\n' "" "" "${auth:-<no author in source>}"
    done
} > "$REPO/SERIES"

echo "patches: $(ls "$REPO"/*.patch | wc -l)"
echo "series lines: $(wc -l < "$REPO/SERIES")"
head -12 "$REPO/SERIES"
