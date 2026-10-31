#!/bin/bash
# Build the board DTB with the Venus node enabled, and diff it against the one
# currently on the FAT partition. Nothing is installed here.
set -euo pipefail
K=$HOME/rocknix-nf/port/repo
D=$HOME/rocknix-nf/distribution/projects/ROCKNIX/devices/SM6115/linux/dts/qcom
OUT=$HOME/rocknix-nf/dtb-venus
NAME=sm6125-retroid-pocket-duo-lite

rm -rf "$OUT"; mkdir -p "$OUT"
cd "$K"

# board dts into the kernel tree so it can see the qcom dtsi and bindings
cp "$D/$NAME.dts" arch/arm64/boot/dts/qcom/
if ! grep -q "&venus" arch/arm64/boot/dts/qcom/$NAME.dts; then
    cat >> arch/arm64/boot/dts/qcom/$NAME.dts <<'EOF'

/* Venus: hardware video decode/encode. The node ships disabled in the SoC dtsi. */
&venus {
	status = "okay";
};
EOF
fi

echo "=== building the dtb"
make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/$NAME.dtb 2>&1 | tail -5
cp arch/arm64/boot/dts/qcom/$NAME.dtb "$OUT/$NAME-venus.dtb"
echo "  built: $(stat -c %s "$OUT/$NAME-venus.dtb") bytes"

echo
echo "=== decompile and compare with the running one"
dtc -I dtb -O dts -o "$OUT/new.dts" "$OUT/$NAME-venus.dtb" 2>/dev/null
if [ -f /tmp/dtb-check/board.dts ]; then
    cp /tmp/dtb-check/board.dts "$OUT/old.dts"
    echo "  nodes added in the new dtb:"
    grep -c "video-codec@" "$OUT/new.dts" | sed 's/^/    video-codec nodes: /'
    echo "  diff summary (lines changed):"
    diff -u "$OUT/old.dts" "$OUT/new.dts" | grep -E '^[+-][^+-]' | sed 's/^/    /' | head -40
    echo "  total differing lines: $(diff -u "$OUT/old.dts" "$OUT/new.dts" | grep -cE '^[+-][^+-]')"
else
    echo "  no old decompile available"
fi

echo
echo "=== venus node status in the new dtb"
grep -A2 "video-codec@5a00000" "$OUT/new.dts" | head -6
