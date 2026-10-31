#!/bin/bash
D="$HOME/rocknix-nf/distribution"
echo "HOME=$HOME"
echo "D=$D exists=$([ -d "$D" ] && echo yes || echo no)"
echo "-- project patches:"
ls "$D/projects/ROCKNIX/patches/linux" 2>/dev/null | wc -l
echo "-- device patches:"
ls "$D/projects/ROCKNIX/devices/SM6115/patches/linux" 2>/dev/null | wc -l
echo "-- how package.mk applies patches:"
grep -nE "patches|PKG_PATCH" "$D/projects/ROCKNIX/packages/linux/package.mk" 2>/dev/null | head -12
echo "-- unpack script:" 
grep -nE "patches|apply" "$D/scripts/unpack" 2>/dev/null | head -12
