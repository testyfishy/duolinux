#!/bin/bash
set -uo pipefail
P=$HOME/rocknix-nf/distribution/projects/ROCKNIX/devices/SM6115/patches/linux
echo "patches: $(ls "$P"/*.patch | wc -l)"
echo "with From: line:        $(grep -l '^From:' "$P"/*.patch 2>/dev/null | wc -l)"
echo "with Signed-off-by:     $(grep -l '^Signed-off-by:' "$P"/*.patch 2>/dev/null | wc -l)"
echo "with Author:            $(grep -l '^Author:' "$P"/*.patch 2>/dev/null | wc -l)"
echo
echo "=== first 10 lines of three patches"
for n in 0060 0072 0006; do
    f=$(ls "$P"/$n-*.patch)
    echo "--- $(basename "$f")"
    sed -n '1,10p' "$f"
    echo
done
echo "=== any copyright/licence lines anywhere in the series"
grep -l -iE "copyright|SPDX-License-Identifier" "$P"/*.patch 2>/dev/null | wc -l
