#!/bin/bash
# Build a test DTB from the vendor blob that adds a VA capture backend:
#   - a "VA Capture" DAI link (q6afedai VA_CODEC_DMA_TX_0 -> q6routing -> vamacro)
#   - qcom,dmic-sample-rate on the vamacro node
#   - #sound-dai-cells on vamacro if the vendor node lacks it
#
# The vendor layout (32-bit soc@0) is preserved because this decompiles and
# recompiles the vendor blob, not our ported tree.
set -euo pipefail
REPO="/mnt/c/Users/user/Documents/Default Project/duolinux"
SRC=$REPO/out/kernel/sm6125-retroid-pocket-duo-lite.dtb
OUT=${1:-$HOME/rocknix-nf/dtb-va-test.dtb}

dtc -I dtb -O dts -o /tmp/va-base.dts "$SRC" 2>/dev/null
cp /tmp/va-base.dts /tmp/va-new.dts

python3 - <<'PY'
import io, sys

p = "/tmp/va-new.dts"
s = io.open(p).read()

LINK = """		va-capture-dai-link {
			link-name = "VA Capture";

			cpu {
				sound-dai = <0xda 0x6e>;
			};

			platform {
				sound-dai = <0xdb>;
			};

			codec {
				sound-dai = <0x97 0x00>;
			};
		};

"""

if "va-capture-dai-link" in s:
    sys.exit("already present")

anchor = "\t\tmm1-dai-link {"
if anchor not in s:
    sys.exit("mm1-dai-link anchor not found")
s = s.replace(anchor, LINK + anchor, 1)

i = s.find('compatible = "qcom,sm6125-lpass-va-macro"')
if i < 0:
    sys.exit("vamacro node not found")
j = s.find("\n\t\t\t};", i)
if j < 0:
    sys.exit("vamacro node end not found")
block = s[i:j]
add = ""
if "#sound-dai-cells" not in block:
    add += "\n\t\t\t#sound-dai-cells = <0x01>;"
if "dmic-sample-rate" not in block:
    add += "\n\t\t\tqcom,dmic-sample-rate = <0x249f00>;"
s = s[:j] + add + s[j:]

io.open(p, "w", newline="\n").write(s)
print("DTB source patched")
PY

dtc -I dts -O dtb -o "$OUT" /tmp/va-new.dts 2>/dev/null

echo "=== result"
ls -l "$OUT" | sed 's/^/  /'
dtc -I dtb -O dts -o /tmp/va-verify.dts "$OUT" 2>/dev/null
echo "  VA Capture link: $(grep -c 'VA Capture' /tmp/va-verify.dts)"
echo "  port 0x6e:       $(grep -c '<0xda 0x6e>' /tmp/va-verify.dts)"
echo "  sample rate:     $(grep -c '0x249f00' /tmp/va-verify.dts)"

echo
echo "=== semantic diff against the vendor blob (expect additions only)"
diff /tmp/va-base.dts /tmp/va-verify.dts | head -30

echo
echo "=== bootloader identity must be unchanged"
grep -A1 'qcom,msm-id\|qcom,board-id' /tmp/va-base.dts | tr -d ' \n' | sed 's/^/  base: /'
echo
grep -A1 'qcom,msm-id\|qcom,board-id' /tmp/va-verify.dts | tr -d ' \n' | sed 's/^/  new:  /'
echo
