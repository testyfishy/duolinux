#!/bin/sh
# Enumerate gain controls and show current vs max, so we know what is actually low.
set -u
amixer -c 0 controls 2>/dev/null | sed -n "s/numid=[0-9]*,iface=MIXER,name='\(.*\)'/\1/p" \
  | grep -iE "pa|volume|boost|gain" > /tmp/gain-controls.txt
echo "=== gain controls (current / max)"
while IFS= read -r c; do
    raw=$(amixer -c 0 sget "$c" 2>/dev/null)
    cur=$(echo "$raw" | grep -oE "\[[0-9]+%\]" | head -1 | tr -d '[]%')
    lim=$(echo "$raw" | grep -oE "Limits: Playback [0-9]+ - [0-9]+" | head -1)
    val=$(echo "$raw" | grep -oE ": values=[0-9]+" | head -1 | cut -d= -f2)
    printf '  %-40s cur=%s%% val=%s  %s\n' "$c" "${cur:-?}" "${val:-?}" "$lim"
done < /tmp/gain-controls.txt
