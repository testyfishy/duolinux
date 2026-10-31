#!/bin/bash
# Reboot the device and wait for SSH to return, then report the kernel.
set -uo pipefail
KEY="$HOME/.ssh/duo_key"
SSH="ssh -i $KEY -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=8 root@192.168.86.33"

echo "=== rebooting"
$SSH 'sync; systemctl reboot' 2>/dev/null || true
sleep 20

ok=0
for i in $(seq 1 36); do
    if out=$($SSH 'uname -r' 2>/dev/null) && [ -n "$out" ]; then
        echo "=== back after ~$((20 + i * 5))s: $out"
        ok=1; break
    fi
    sleep 5
done

if [ "$ok" = 0 ]; then
    echo "=== NOT BACK after 200s"
    exit 1
fi

$SSH 'echo "kernel:  $(uname -r)"; echo "root:    $(findmnt -no SOURCE /)"; echo "uptime:  $(uptime -p)"; systemctl --failed --no-legend | head -5; echo "failed units: $(systemctl list-units --state=failed --no-legend | wc -l)"'
