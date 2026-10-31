#!/bin/bash
# Make the TX macro DMIC clock settings runtime-tunable, so the right divider and
# enable bit can be found by sweeping parameters instead of rebuilding.
#
# CDC_TX_TOP_CSR_SWR_DMICn_CTL resets to 0x0E (divider field 7 - invalid - and
# bit 0 clear) and mainline never writes it. The field values are 2 * index:
# DIV2=0, DIV3=2, DIV4=4, DIV6=6, DIV8=8, DIV16=10.
#
#   /sys/module/snd_soc_lpass_tx_macro/parameters/dmic_div
#   /sys/module/snd_soc_lpass_tx_macro/parameters/dmic_en
#
# Written when the macro MCLK is enabled (each capture stream), so a value can be
# tried by writing the parameter and starting a new recording.
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

if "dmic_div" in src:
    sys.exit("already patched")

# tunables, declared before the mclk enable helper
anchor = "static int tx_macro_mclk_enable(struct tx_macro *tx,\n\t\t\t\tbool mclk_enable)\n"
if anchor not in src:
    sys.exit("mclk helper not found")
params = (
"/*\n"
" * DMIC clock control. The register resets with the divider field invalid (7)\n"
" * and bit 0 clear, and nothing else programs it. Field values are 2 * index:\n"
" * DIV2=0, DIV3=2, DIV4=4, DIV6=6, DIV8=8, DIV16=10.\n"
" */\n"
"static int dmic_div = 4;\n"
"static int dmic_en;\n"
"module_param(dmic_div, int, 0644);\n"
"module_param(dmic_en, int, 0644);\n"
"\n")
src = src.replace(anchor, params + anchor, 1)

old = """			regcache_mark_dirty(regmap);
			regcache_sync(regmap);
"""
new = """			regcache_mark_dirty(regmap);
			regcache_sync(regmap);
			/*
			 * Program both DMIC clock outputs. The divider field sits in
			 * bits [3:1]; bit 0 is cleared by reset and may be an enable.
			 */
			{
				unsigned int v = ((dmic_div & 0xf) << 1) | (dmic_en & 1);

				regmap_update_bits(regmap, CDC_TX_TOP_CSR_SWR_DMIC0_CTL,
						   GENMASK(3, 0), v);
				regmap_update_bits(regmap, CDC_TX_TOP_CSR_SWR_DMIC1_CTL,
						   GENMASK(3, 0), v);
			}
"""
if old not in src:
    sys.exit("mclk enable block not found")
src = src.replace(old, new, 1)

io.open(p, "w", newline="\n").write(src)
print("patched: dmic_div / dmic_en module parameters")
PY

git diff -- "$F" > "$P/0003-tx-macro-dmic-clock-tunables.patch"
echo "  patch: $(wc -l < "$P/0003-tx-macro-dmic-clock-tunables.patch") lines"
grep -n "dmic_div\|dmic_en\|GENMASK(3, 0)" "$F" | head -10 | sed 's/^/  /'
