#!/bin/bash
set -uo pipefail
F=$HOME/rocknix-nf/port/repo/arch/arm64/boot/dts/qcom/sm6125-retroid-pocket-duo-lite.dts
echo "file: $F"
echo "=== last 14 lines"
tail -14 "$F"
echo "=== line endings"
file "$F"
echo "=== dtc errors in detail"
cd "$HOME/rocknix-nf/port/repo"
cpp -nostdinc -I include -I arch/arm64/boot/dts -I arch/arm64/boot/dts/qcom -undef -D__DTS__ -x assembler-with-cpp \
    arch/arm64/boot/dts/qcom/sm6125-retroid-pocket-duo-lite.dts -o /tmp/board-pre.dts 2>&1 | head -5
dtc -I dts -O dtb -o /tmp/board-test.dtb /tmp/board-pre.dts 2>&1 | head -10
