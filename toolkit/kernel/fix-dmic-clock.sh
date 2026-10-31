#!/bin/bash
# Clock the DMIC at MCLK/4 (2.4 MHz) instead of the hardcoded MCLK/2 (4.8 MHz).
#
# The vendor device tree asks for qcom,tx-dmic-sample-rate = <0x249f00>, i.e.
# 2.4 MHz. Mainline's TX macro writes CDC_TX_SWR_MIC_CLK_DEFAULT (0) into
# CDC_TX_SWR_DMICn_CTL, and the driver's own comment says that is "DIV2":
# 9.6 MHz / 2 = 4.8 MHz, above the limit of a normal PDM microphone, so the
# microphone tri-states its data line.
#
# Field encoding (bits 3:1, from the VA macro driver's constants):
#   DIV2=0x0  DIV3=0x2  DIV4=0x4  DIV6=0x6  DIV8=0x8  DIV16=0xa
# so DIV4 (4.8/2 = 2.4 MHz from a 9.6 MHz MCLK) is the value 4.
set -euo pipefail
K=$HOME/rocknix-nf/port/repo
F=$K/sound/soc/codecs/lpass-tx-macro.c
P=$HOME/rocknix-nf/port/patches
mkdir -p "$P"

cd "$K"
git checkout -q -- "$F"
python3 - "$F" <<'PY'
import io, re, sys

p = sys.argv[1]
src = io.open(p).read()

if "CDC_TX_SWR_DMIC_CLK_DIV4" in src:
    sys.exit("already patched")

# document the constant next to the existing default
src = src.replace(
    "#define CDC_TX_SWR_MIC_CLK_DEFAULT\t0\n",
    "#define CDC_TX_SWR_MIC_CLK_DEFAULT\t0\n"
    "/* DIV4: 9.6 MHz MCLK / 4 = 2.4 MHz PDM clock, as the vendor tree asks for */\n"
    "#define CDC_TX_SWR_DMIC_CLK_DIV4\t4\n", 1)

# only the DMIC clock writes; the AMIC ones stay at the default
pat = re.compile(r'(CDC_TX_SWR_DMIC_CLK_SEL_MASK,\s*\n\s*)CDC_TX_SWR_MIC_CLK_DEFAULT')
src, n = pat.subn(r'\1CDC_TX_SWR_DMIC_CLK_DIV4', src)
if n != 3:
    sys.exit("expected 3 DMIC clock write sites, patched %d" % n)

io.open(p, "w", newline="\n").write(src)
print("patched %d DMIC clock write sites" % n)
PY

git diff -- "$F" > "$P/0003-tx-macro-clock-the-dmic-at-2.4MHz.patch"
echo "  patch: $(wc -l < "$P/0003-tx-macro-clock-the-dmic-at-2.4MHz.patch") lines"
grep -n "CDC_TX_SWR_DMIC_CLK_DIV4" "$F" | sed 's/^/  /'
