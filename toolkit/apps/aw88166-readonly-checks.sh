#!/bin/sh
# Read-only checks before touching volume: profile, register values, per-amp state.
set -u
echo "=== profile enum for each amp"
for n in "SPK_L AW88166 Profile Set" "SPK_R AW88166 Profile Set"; do
    echo "  $n:"
    amixer -c 0 sget "$n" 2>&1 | sed 's/^/    /' | head -4
done

echo
echo "=== all aw88166 controls as ALSA sees them (id, name, values)"
amixer -c 0 contents 2>/dev/null | awk '
  /^numid=/ {id=$0}
  /name=/ {name=$0}
  /: values=/ {print "  " id " | " name " | " $0}
' 2>/dev/null | grep -iE "SPK_|aw88166" | head -20

echo
echo "=== regmap debugfs available?"
mountpoint -q /sys/kernel/debug || { mount -t debugfs none /sys/kernel/debug 2>/dev/null; }
ls -d /sys/kernel/debug/regmap/0-0034 /sys/kernel/debug/regmap/0-0035 2>/dev/null || echo "  regmap debugfs not exposed"

for a in 0-0034 0-0035; do
    f=/sys/kernel/debug/regmap/$a/registers
    [ -r "$f" ] || continue
    echo "  --- $a"
    # register 05 = volume (bits 15:6), register 01 = status
    grep -E "^0[0-9a-f]:|^00:|^01:|^05:" "$f" 2>/dev/null | head -4 | sed 's/^/    /'
done

echo
echo "=== dmesg: per-amp start results"
dmesg | grep -iE "aw88166" | tail -4 | sed 's/^/  /'
