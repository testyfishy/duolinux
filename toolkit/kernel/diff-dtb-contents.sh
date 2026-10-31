#!/bin/bash
# Compare the vendor DTB against the rebuilt one property by property.
#
# Same node set is not enough: a changed reg value, clock frequency or supply
# can leave the display dark while the tree still parses. __symbols__ is
# present only in the vendor build and is not comparable.
set -uo pipefail
sed '/__symbols__ {/,/};/d' /tmp/orig.dts > /tmp/orig.nosym.dts
sed '/__symbols__ {/,/};/d' /tmp/new.dts  > /tmp/new.nosym.dts

echo "=== sizes after dropping __symbols__"
wc -l /tmp/orig.nosym.dts /tmp/new.nosym.dts | sed 's/^/  /'

echo
echo "=== property-level differences (first 80 lines)"
diff -u /tmp/orig.nosym.dts /tmp/new.nosym.dts | sed -n '1,80p'

echo
echo "=== difference count"
diff -u /tmp/orig.nosym.dts /tmp/new.nosym.dts | grep -cE '^[+-][^+-]'
