#!/bin/bash
# Which vendor DTB is the Duo Lite, and what does it say about the microphone?
set -uo pipefail
D=$HOME/android-images

for dir in vendor_boot_a dtbo_a; do
    echo "=== $dir"
    for f in "$D/$dir"/*.dts; do
        [ -f "$f" ] || continue
        model=$(grep -m1 -oE 'model = "[^"]*"' "$f" | head -1)
        dmic=$(grep -c -i 'dmic' "$f")
        bias=$(grep -c -iE 'mic-bias|micbias|MIC BIAS' "$f")
        route=$(grep -c 'audio-routing' "$f")
        va=$(grep -c -iE 'va_macro|va-macro|vamacro' "$f")
        [ "$dmic" = 0 ] && [ "$route" = 0 ] && continue
        printf '  %-12s dmic=%-3s bias=%-3s route=%-3s va=%-3s %s\n' \
            "$(basename "$f")" "$dmic" "$bias" "$route" "$va" "$model"
    done
done

echo
echo "=== board identity in each vendor DTB"
for f in "$D"/vendor_boot_a/*.dts; do
    echo "  $(basename "$f"): $(grep -m1 -oE 'model = "[^"]*"' "$f")"
done
