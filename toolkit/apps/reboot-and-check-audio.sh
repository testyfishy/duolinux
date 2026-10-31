#!/bin/bash
# Clean reboot, then a bypassed test: a 1 kHz tone straight to the speaker PCM,
# so we learn whether the amp path works at all without PipeWire in the middle.
set -uo pipefail
KEY=$HOME/.ssh/duo_key
H=root@192.168.1.33
SSH="ssh -i $KEY -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=10"

echo "=== rebooting"
$SSH "$H" 'sync; systemctl reboot' 2>/dev/null || true
sleep 25
for i in $(seq 1 24); do
    if $SSH "$H" 'true' 2>/dev/null; then echo "  back"; break; fi
    sleep 5
done
sleep 10

$SSH "$H" '
echo "=== card state after reboot"
aplay -l 2>/dev/null | head -4
echo "=== mixer readable again?"
amixer -c 0 sget "SPK_L Speaker Switch" 2>&1 | head -2
echo "=== amp registers"
for a in 0-0034 0-0035; do echo "  $a: $(grep -E "^01:|^05:" /sys/kernel/debug/regmap/$a/registers 2>/dev/null | tr "\n" " ")"; done
'
