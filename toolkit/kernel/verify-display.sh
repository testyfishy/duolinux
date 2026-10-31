#!/bin/bash
# Display-path verification for the 7.2.11 port, before any reboot.
# A successful build does not prove a working panel; this checks the parts that
# only differ by accident when a port goes wrong.
set -uo pipefail
cd "$HOME/rocknix-nf/port/repo"
BR=rk-7.2.11-full
OUT=$HOME/rocknix-nf/display-review

mkdir -p "$OUT"
echo "=== 1. files touching the display path"
git diff --name-only v7.2.11-base $BR -- \
    drivers/gpu/drm/panel/ drivers/gpu/drm/bridge/ drivers/gpu/drm/msm/ \
    drivers/backlight/ drivers/gpu/drm/msm/disp/dpu1/ \
    arch/arm64/boot/dts/qcom/ | tee "$OUT/files.txt"
echo

echo "=== 2. full source diff for review ($(wc -l < "$OUT/files.txt") files)"
git diff v7.2.11-base $BR -- \
    drivers/gpu/drm/panel/ drivers/gpu/drm/bridge/ drivers/gpu/drm/msm/ \
    drivers/backlight/ arch/arm64/boot/dts/qcom/ > "$OUT/display.diff"
echo "  $OUT/display.diff ($(wc -l < "$OUT/display.diff") lines)"

echo
echo "=== 3. panel/bridge drivers: init sequence, delays, reset, modes must be unchanged"
for d in drivers/gpu/drm/panel/panel-himax-hx83112a.c \
         drivers/gpu/drm/bridge/wl818s*.c; do
    [ -f "$d" ] || { echo "  MISSING $d"; continue; }
    echo "  $d: $(git diff --numstat v7.2.11-base $BR -- "$d" | awk '{print "+"$1" -"$2}')"
done

echo
echo "=== 4. DPU / DSI diffs (the 0200-0211 series) vs what 7.2.0 had"
git diff v7.2.11-base $BR -- drivers/gpu/drm/msm/dsi/ > "$OUT/dsi.diff"
git diff v7.2.11-base $BR -- drivers/gpu/drm/msm/disp/dpu1/ > "$OUT/dpu.diff"
echo "  dsi.diff $(wc -l < "$OUT/dsi.diff") lines, dpu.diff $(wc -l < "$OUT/dpu.diff") lines"

echo
echo "=== 5. DT: panel/bridge compatibles and supplies referenced by this board"
for c in "himax,hx83112a" "wl818s" "retroid" "duo"; do
    echo "  $c: $(grep -ril "$c" arch/arm64/boot/dts/qcom/ 2>/dev/null | wc -l) dts files"
done
grep -rn "hx83112a\|wl818s" arch/arm64/boot/dts/qcom/*.dts* 2>/dev/null | head -8

echo
echo "=== 6. hunk-level check of the two patches that must never be dropped"
git log --oneline v7.2.11-base..$BR | grep -E "0060|0065" | sed 's/^/  /'
