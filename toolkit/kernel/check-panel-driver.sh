#!/bin/bash
set -uo pipefail
W=$HOME/rocknix-nf
cd "$W/port/repo"
echo "=== who matches retroidpocket,duolite-hx83112a?"
grep -rn "duolite-hx83112a" drivers/ | head
echo
f=$(grep -rln "duolite-hx83112a" drivers/gpu/drm/panel/ | head -1)
echo "driver: $f"
grep -n -B4 -A20 "of_device_id" "$f" | head -40
echo
echo "=== its Kconfig symbol"
k=$(dirname "$f")/Kconfig
g=$(grep -B8 -A6 "duolite\|retroid" "$k" | head -30); echo "$g"
echo
echo "=== is it in either config?"
for s in $(grep -oE '^config [A-Z0-9_]+' "$k" | awk '{print $2}' | grep -iE "HX83112|RETROID|DUO"); do
    echo "  $s: new=$(grep -E "^$s=" "$W/config-7.2.11-nf" || echo unset) old=$(grep -E "^$s=" "$W/config-7.2.0-nf" || echo unset)"
done
echo
echo "=== compatible in the new kernel image?"
grep -cxF "retroidpocket,duolite-hx83112a" /tmp/dtb-check/img.str || echo 0
grep -c "duolite-hx83112a" "$W/stage-7.2.11/lib/modules/7.2.11-nf/modules.alias" || true
