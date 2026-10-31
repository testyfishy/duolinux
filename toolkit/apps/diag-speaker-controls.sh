#!/bin/sh
# Read the speaker amplifier / route controls by numid, which avoids name quirks.
set -u
echo "=== amplifier and speaker controls"
for id in 17 18 19 20 21 22 23 24 25 26 27 33 34 91 99 1140 1142 1143; do
    out=$(amixer -c 0 cget numid=$id 2>/dev/null)
    [ -n "$out" ] || continue
    name=$(echo "$out" | sed -n "s/numid=[0-9]*,iface=[A-Z]*,name='\(.*\)'/\1/p" | head -1)
    [ -z "$name" ] && name=$(echo "$out" | head -1)
    val=$(echo "$out" | grep -oE ": values=[0-9]+(,[0-9]+)*" | head -1)
    lim=$(echo "$out" | grep -oE "min=[0-9]+,max=[0-9]+" | head -1)
    echo "  $id  $name  $val  $lim"
done

echo
echo "=== search for anything named PA / speaker"
amixer -c 0 controls 2>/dev/null | grep -iE "pa |speaker|spk" | head -10 | sed 's/^/  /'

echo
echo "=== playback route switches that carry audio to the amp"
amixer -c 0 controls 2>/dev/null | grep -iE "switch" | grep -iE "spk|ear|rx|pa" | head -10 | sed 's/^/  /'
