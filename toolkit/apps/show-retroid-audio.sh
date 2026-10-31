#!/bin/bash
# Show Retroid's audio block from their published Duo DTS: DAI links, routing,
# and the VA macro / amp nodes. This is the reference we can port.
set -uo pipefail
D=$HOME/retroid-dts
echo "=== DAI links and routing (common dtsi lines 185-300)"
sed -n '185,300p' "$D/eliza-retroidpocket-common.dtsi"

echo
echo "=== VA macro node"
grep -n -A18 "lpass_vamacro:" "$D/eliza-retroidpocket-common.dtsi" | head -24

echo
echo "=== amp node (SPK_L) in full"
sed -n '794,815p' "$D/eliza-retroidpocket-common.dtsi"

echo
echo "=== ELIZA UCM file in full"
cat /home/user/retroid-ucm/ucm2/RetroidPocket/ELIZA/ELIZA-RetroidPocket-I2S.conf
