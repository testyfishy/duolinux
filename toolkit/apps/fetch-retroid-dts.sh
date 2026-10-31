#!/bin/bash
# Pull Retroid's published mainline DTS for the Duo and show how it wires the
# audio block: AW88166 amps, ES8326 headset, and the on-board DMIC.
set -uo pipefail
D=$HOME/retroid-dts
BASE=https://raw.githubusercontent.com/RetroidPocket/linux/retroidpocket/v7.3/arch/arm64/boot/dts/qcom

mkdir -p "$D"
for f in eliza-retroidpocket-rpduo.dts eliza-retroidpocket-common.dtsi; do
    curl -sL "$BASE/$f" -o "$D/$f"
    echo "$f: $(wc -l < "$D/$f") lines, $(stat -c %s "$D/$f") bytes"
done

echo
echo "=== audio references in the board DTS"
grep -n -iE 'sound|audio|dmic|vamacro|va-macro|aw88|micbias|mic-bias' "$D/eliza-retroidpocket-rpduo.dts" | head -25

echo
echo "=== audio references in the common dtsi"
grep -n -iE 'sound|audio|dmic|vamacro|va-macro|aw88|micbias|mic-bias' "$D/eliza-retroidpocket-common.dtsi" | head -25
