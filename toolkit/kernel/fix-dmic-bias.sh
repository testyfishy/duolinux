#!/bin/bash
# Give the digital microphones their supply.
#
# The stock Android device tree (dtbo overlay, trinket IDP audio) routes:
#
#     "TX DMIC2", "Digital Mic2", "TX DMIC2", "MIC BIAS1",
#     "TX DMIC3", "Digital Mic3", "TX DMIC3", "MIC BIAS1",
#
# so the DMIC pair on gpio127/128 is powered from the WCD9370's MIC BIAS1.
# The mainline card's audio-routing array only lists the speakers and the
# headset (AMIC2/MIC BIAS2), so MIC BIAS1 is never switched on. An unpowered
# PDM microphone holds its data line at a constant level, which is exactly the
# "exact digital zero" every DMIC input produced.
#
# Same spelling is used by mainline boards with this codec (sm8450-hdk,
# sm8550-mtp/qrd): "TX DMICn" is a DAPM input in lpass-tx-macro, "MIC BIASn"
# is a supply widget in wcd937x.
set -euo pipefail
K=$HOME/rocknix-nf/port/repo
F=$K/arch/arm64/boot/dts/qcom/sm6125-retroid-pocket-duo-lite.dts
P=$HOME/rocknix-nf/port/patches
mkdir -p "$P"

cd "$K"
git checkout -q -- "$F" 2>/dev/null || true

python3 - "$F" <<'PY'
import io, sys

p = sys.argv[1]
src = io.open(p).read()

if '"TX DMIC2", "MIC BIAS1"' in src:
    print("already patched")
    raise SystemExit(0)

old = """				"AMIC2", "MIC BIAS2",
				"TX SWR_INPUT1", "ADC2_OUTPUT";
"""
new = """				"AMIC2", "MIC BIAS2",
				"TX SWR_INPUT1", "ADC2_OUTPUT",
				/* The DMIC pair on gpio127/128 is powered from the
				 * codec's MIC BIAS1 (see the vendor overlay). Without
				 * this route the bias never turns on and the mics hold
				 * their data line at a constant level. */
				"TX DMIC2", "MIC BIAS1",
				"TX DMIC3", "MIC BIAS1";
"""
if old not in src:
    sys.exit("audio-routing block not found")
src = src.replace(old, new, 1)
io.open(p, "w", newline="\n").write(src)
print("patched audio-routing")
PY

# The board DTS is untracked in the ported tree, so diff it against ROCKNIX's
# pristine copy. That diff is the complete list of this board's deltas.
BASE=$HOME/rocknix-nf/distribution/projects/ROCKNIX/devices/SM6115/linux/dts/qcom/sm6125-retroid-pocket-duo-lite.dts
if [ -f "$BASE" ]; then
    { echo "# Board deltas for sm6125-retroid-pocket-duo-lite.dts against ROCKNIX"; \
      echo "# (audio routing for the DMIC supply, plus the Venus enable)"; } > "$P/0002-dts-duo-lite-board-deltas.patch"
    diff -u "$BASE" "$F" >> "$P/0002-dts-duo-lite-board-deltas.patch" || true
    rm -f "$P/0002-dts-duo-lite-power-the-dmic-from-mic-bias1.patch"
    echo "  patch: $(wc -l < "$P/0002-dts-duo-lite-board-deltas.patch") lines"
fi
echo
sed -n '/audio-routing/,/;/p' "$F" | sed 's/^/  /'
