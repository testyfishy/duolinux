#!/bin/bash
# Verify the fdtput-patched vendor DTB: parses, keeps the vendor layout, and
# differs from the original only inside the audio-routing property.
set -uo pipefail
VENDOR="/mnt/c/Users/HTPC-Aran/Documents/Default Project/duolinux/out/kernel/sm6125-retroid-pocket-duo-lite.dtb"
PATCHED="$HOME/rocknix-nf/dtb-vendor-dmic-fdtput.dtb"

echo "sizes: vendor=$(stat -c %s "$VENDOR")  patched=$(stat -c %s "$PATCHED")"
echo "model: $(fdtget -t s "$PATCHED" / model 2>&1)"
echo "soc #address-cells: $(fdtget "$PATCHED" /soc@0 '#address-cells' 2>&1)"
echo "changed bytes vs vendor: $(cmp -l "$VENDOR" "$PATCHED" | wc -l)"
echo "routing:"
fdtget -t s "$PATCHED" /sound audio-routing | tr ' ' '\n' | sed 's/^/  /'

echo
if dtc -I dtb -O dts -o /tmp/fdtput.dts "$PATCHED" 2>/dev/null; then
    echo "dtc: parses ok, $(grep -cE '^\s*[a-zA-Z0-9_@,.-]+ \{' /tmp/fdtput.dts) nodes"
    echo "soc cells in parsed tree:"
    awk '/soc@0 \{/{f=1} f&&/#address-cells/{print "  " $0; exit}' /tmp/fdtput.dts
else
    echo "dtc: FAILED to parse the patched blob"
fi
