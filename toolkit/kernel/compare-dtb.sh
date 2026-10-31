#!/bin/bash
# What did the rebuilt DTB lose compared with the ROCKNIX one?
#
# Our board DTS compiles against the ported 7.2.11 tree, while the DTB that was
# on the device came from ROCKNIX's own tree. If the two disagree about which
# devices exist, the kernel can boot with no network or no display.
set -uo pipefail
ORIG="/mnt/c/Users/user/Documents/Default Project/duolinux/out/kernel/sm6125-retroid-pocket-duo-lite.dtb"
NEW=$HOME/rocknix-nf/port/repo/arch/arm64/boot/dts/qcom/sm6125-retroid-pocket-duo-lite.dtb

dtc -I dtb -O dts -o /tmp/orig.dts "$ORIG" 2>/dev/null
dtc -I dtb -O dts -o /tmp/new.dts  "$NEW"  2>/dev/null

for pair in "original:/tmp/orig.dts:$ORIG" "rebuild:/tmp/new.dts:$NEW"; do
    name=${pair%%:*}; rest=${pair#*:}; dts=${rest%%:*}; dtb=${rest#*:}
    echo "$name: $(stat -c %s "$dtb") bytes, $(grep -cE '^\s*[a-zA-Z0-9_@,.-]+ \{' "$dts") nodes"
done

paths() { grep -oE '^\s*[a-zA-Z0-9_@,.-]+ \{' "$1" | sed 's/^[[:space:]]*//; s/ {$//' | sed 's/@.*//' | sort -u; }
paths /tmp/orig.dts > /tmp/orig.nodes
paths /tmp/new.dts  > /tmp/new.nodes

echo
echo "=== node names in the original but missing from the rebuild"
comm -23 /tmp/orig.nodes /tmp/new.nodes | sed 's/^/  /' | head -50
echo
echo "=== node names in the rebuild but not in the original"
comm -13 /tmp/orig.nodes /tmp/new.nodes | sed 's/^/  /' | head -20

echo
echo "=== critical nodes"
for n in ethernet wifi wcn3990 bluetooth panel panel-bottom i2c spi; do
    printf '  %-14s original=%s rebuild=%s\n' "$n" \
        "$(grep -c "\b$n" /tmp/orig.dts)" "$(grep -c "\b$n" /tmp/new.dts)"
done
