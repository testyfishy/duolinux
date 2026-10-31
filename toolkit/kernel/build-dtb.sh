#!/bin/bash
# Build the board DTB.
#
# The ROCKNIX port drops sm6125-retroid-pocket-duo-lite.dts into the tree but
# never adds it to arch/arm64/boot/dts/qcom/Makefile, so `make dtbs` silently
# skips it and the image on the FAT partition never changes. This registers it
# and builds only that DTB.
set -euo pipefail
K=$HOME/rocknix-nf/port/repo
MK=$K/arch/arm64/boot/dts/qcom/Makefile
DTB=sm6125-retroid-pocket-duo-lite.dtb

if ! grep -q "$DTB" "$MK"; then
    echo "adding $DTB to the qcom Makefile"
    python3 - "$MK" <<'PY'
import io, sys
p = sys.argv[1]
src = io.open(p).read()
anchor = "dtb-$(CONFIG_ARCH_QCOM)\t+= sm6125-sony-xperia-seine-pdx201.dtb\n"
if anchor not in src:
    sys.exit("anchor not found in Makefile")
src = src.replace(anchor, "dtb-$(CONFIG_ARCH_QCOM)\t+= sm6125-retroid-pocket-duo-lite.dtb\n" + anchor, 1)
io.open(p, "w", newline="\n").write(src)
print("  patched Makefile")
PY
fi

cd "$K"
echo "=== building $DTB"
make -j"$(nproc)" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION=-nf \
     "qcom/$DTB" >/tmp/dtb-build.log 2>&1 || { tail -20 /tmp/dtb-build.log; exit 1; }

D=$K/arch/arm64/boot/dts/qcom/$DTB
ls -l "$D"
echo "=== contents check"
echo "  MIC BIAS1 references: $(strings "$D" | grep -c 'MIC BIAS1')"
echo "  audio-routing strings: $(strings "$D" | grep -c 'TX DMIC')"
