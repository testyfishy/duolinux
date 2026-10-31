#!/bin/bash
# Add the DMIC supply route to the *vendor* DTB instead of rebuilding ours.
#
# Rebuilding the board DTS from the ported tree changes the SoC bus layout
# (32-bit -> 64-bit #address-cells/ranges), and that image would not boot. The
# vendor DTB does boot with our kernel, so patch it directly: decompile, add the
# two routing strings, recompile. Nothing else in the tree changes.
set -euo pipefail
REPO="/mnt/c/Users/user/Documents/Default Project/duolinux"
SRC=$REPO/out/kernel/sm6125-retroid-pocket-duo-lite.dtb
OUT=${1:-$HOME/rocknix-nf/dtb-vendor-with-dmic.dtb}

dtc -I dtb -O dts -o /tmp/vendor.dts "$SRC"
cp /tmp/vendor.dts /tmp/vendor.orig.dts

python3 - <<'PY'
import io
p = "/tmp/vendor.dts"
s = io.open(p).read()
anchor = '"TX SWR_INPUT1", "ADC2_OUTPUT";'
if anchor not in s:
    raise SystemExit("audio-routing tail not found")
if '"TX DMIC2", "MIC BIAS1"' in s:
    raise SystemExit("already routed")
s = s.replace(anchor,
    '"TX SWR_INPUT1", "ADC2_OUTPUT", "TX DMIC2", "MIC BIAS1", "TX DMIC3", "MIC BIAS1";', 1)
io.open(p, "w", newline="\n").write(s)
print("routing added")
PY

dtc -I dts -O dtb -o "$OUT" /tmp/vendor.dts

echo "=== result"
ls -l "$OUT" "$SRC" | sed 's/^/  /'
echo "  MIC BIAS1 strings: $(strings "$OUT" | grep -c 'MIC BIAS1')"
echo "  TX DMIC strings:   $(strings "$OUT" | grep -c 'TX DMIC')"

echo
echo "=== confirming nothing else changed"
dtc -I dtb -O dts -o /tmp/vendor.new.dts "$OUT"
diff -u /tmp/vendor.orig.dts /tmp/vendor.new.dts | grep -E '^[+-]' | grep -v '^[+-][+-]' | head -10
