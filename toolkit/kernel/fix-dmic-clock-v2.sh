#!/bin/bash
# Enable the TX macro's DMIC clock outputs.
#
# CDC_TX_TOP_CSR_SWR_DMICn_CTL (0x00C0/0x00C4) resets to 0x0E: bit 0 (enable) is
# clear and the divider field [3:1] holds an invalid 7. Nothing in mainline ever
# writes it - the only writes are in the DEC mux put handlers, and they never
# fire here (verified: flipping TX DMIC MUX0 and TX DEC0 MUX leaves the register
# at 0x0E).
#
# Same layout as the VA macro (CDC_VA_DMIC_EN_MASK = BIT(0),
# CDC_VA_DMIC_CLK_SEL_MASK = GENMASK(3,1)), where the field value is
# 2 * (divider index): DIV2=0, DIV3=2, DIV4=4, DIV6=6, DIV8=8, DIV16=0xa.
#
# With the 9.6 MHz MCLK the macro selects, DIV4 gives a 2.4 MHz PDM clock - the
# value the board's own device tree asks for (qcom,tx-dmic-sample-rate =
# <0x249f00>). DIV2 (4.8 MHz) is above a PDM microphone's limit, which is why
# the mic tri-states and the capture is garbage.
#
# The write happens when the macro's MCLK is enabled, i.e. for every capture
# stream, and is undone with the MCLK.
set -euo pipefail
K=$HOME/rocknix-nf/port/repo
F=$K/sound/soc/codecs/lpass-tx-macro.c
P=$HOME/rocknix-nf/port/patches
mkdir -p "$P"

cd "$K"
git checkout -q -- "$F"
python3 - "$F" <<'PY'
import io, sys

p = sys.argv[1]
src = io.open(p).read()

if "CDC_TX_SWR_DMIC_CLK_EN" in src:
    sys.exit("already patched")

# constants next to the existing mask
src = src.replace(
    "#define CDC_TX_SWR_DMIC_CLK_SEL_MASK\tGENMASK(3, 1)\n",
    "#define CDC_TX_SWR_DMIC_CLK_SEL_MASK\tGENMASK(3, 1)\n"
    "#define CDC_TX_SWR_DMIC_CLK_EN\t\tBIT(0)\n"
    "/* divider field value: 2 * index, so DIV4 = MCLK/4 = 2.4 MHz from 9.6 MHz */\n"
    "#define CDC_TX_SWR_DMIC_CLK_DIV4_VAL\t(4 << 1)\n", 1)

old = """			regcache_mark_dirty(regmap);
			regcache_sync(regmap);
"""
new = """			regcache_mark_dirty(regmap);
			regcache_sync(regmap);
			/*
			 * The DMIC clock outputs reset disabled (0x0E) and nothing
			 * else programs them. Clock both pairs at MCLK/4 = 2.4 MHz:
			 * a PDM microphone tri-states its data line when clocked
			 * much above 3 MHz, which is what the board saw.
			 */
			regmap_update_bits(regmap, CDC_TX_TOP_CSR_SWR_DMIC0_CTL,
					   CDC_TX_SWR_DMIC_CLK_SEL_MASK |
					   CDC_TX_SWR_DMIC_CLK_EN,
					   CDC_TX_SWR_DMIC_CLK_DIV4_VAL |
					   CDC_TX_SWR_DMIC_CLK_EN);
			regmap_update_bits(regmap, CDC_TX_TOP_CSR_SWR_DMIC1_CTL,
					   CDC_TX_SWR_DMIC_CLK_SEL_MASK |
					   CDC_TX_SWR_DMIC_CLK_EN,
					   CDC_TX_SWR_DMIC_CLK_DIV4_VAL |
					   CDC_TX_SWR_DMIC_CLK_EN);
"""
if old not in src:
    sys.exit("MCLK enable block not found")
src = src.replace(old, new, 1)

io.open(p, "w", newline="\n").write(src)
print("patched the MCLK enable path")
PY

git diff -- "$F" > "$P/0003-tx-macro-enable-the-dmic-clock-at-2.4MHz.patch"
echo "  patch: $(wc -l < "$P/0003-tx-macro-enable-the-dmic-clock-at-2.4MHz.patch") lines"
sed -n '/The DMIC clock outputs reset disabled/,/CDC_TX_SWR_DMIC_CLK_EN);/p' "$F" | head -20 | sed 's/^/  /'
