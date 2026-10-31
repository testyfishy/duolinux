#!/bin/sh
set -u
echo "=== ALSA cards"
cat /proc/asound/cards 2>/dev/null
echo "  aplay -l:"; aplay -l 2>&1 | head -8

echo
echo "=== sound errors in dmesg (this boot)"
dmesg | grep -iE "asoc|sound|lpass|sm8250|q6afe|q6asm|adsp|audio" | grep -iE "error|fail|timeout|defer" | head -10
echo "  (count: $(dmesg | grep -iE "asoc|sound|lpass|sm8250|q6afe|q6asm|adsp" | grep -icE "error|fail|timeout"))"

echo
echo "=== same on the previous (7.2.0-nf) boot"
echo "  errors: $(journalctl -b -1 -k --no-pager 2>/dev/null | grep -iE "asoc|sound|lpass|sm8250|q6afe|q6asm|adsp" | grep -icE "error|fail|timeout")"
echo "  cards seen: $(journalctl -b -1 --no-pager 2>/dev/null | grep -ci 'sound card')"

echo
echo "=== is the JEITA code actually in this kernel?"
echo "  jeita symbols: $(grep -c "bq256xx_jeita" /proc/kallsyms)"
grep -oE "bq256xx_jeita[a-z_]*" /proc/kallsyms | sort -u | head -5

echo
echo "=== adsp remoteproc detail"
for r in /sys/class/remoteproc/*; do
    echo "  $(basename "$r"): $(cat "$r/state") firmware=$(cat "$r/firmware" 2>/dev/null)"
done
