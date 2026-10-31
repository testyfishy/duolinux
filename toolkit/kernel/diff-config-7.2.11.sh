#!/bin/bash
# Config diff 7.2.0-nf -> 7.2.11-nf.
# Everything that changes matters; the display and netfilter groups matter most.
set -uo pipefail
W=$HOME/rocknix-nf
P=$W/port/repo
A=$W/config-7.2.0-nf
B=${1:-$W/config-7.2.11-nf}

[ -f "$A" ] || { echo "missing $A"; exit 1; }
[ -f "$B" ] || { echo "missing $B"; exit 1; }

echo "=== totals"
"$P/scripts/diffconfig" "$A" "$B" > /tmp/cfg.diff || true
echo "  added:   $(grep -c '^+ ' /tmp/cfg.diff)"
echo "  removed: $(grep -c '^- ' /tmp/cfg.diff)"
echo "  changed: $(grep -c '^[a-zA-Z].*->' /tmp/cfg.diff)"

echo
echo "=== display / GPU (must be empty unless explained)"
grep -E "PANEL|DRM_MSM|DSI|BACKLIGHT|BRIDGE|DPU|GPU_DEVFREQ|ADRENO|DRM_DISPLAY" /tmp/cfg.diff | head -25

echo
echo "=== netfilter / networking (intended to be unchanged)"
grep -E "NFT|NF_TABLES|NETFILTER|IP_NF|IP6_NF|TUN|MULTIPLE_TABLES" /tmp/cfg.diff | head -25

echo
echo "=== power / charging / battery"
grep -E "BQ256|CX221|POWER_SUPPLY|CHARGER|SMBX|PMIC|THERMAL" /tmp/cfg.diff | head -20

echo
echo "=== full diff"
cat /tmp/cfg.diff
