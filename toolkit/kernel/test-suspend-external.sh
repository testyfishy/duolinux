#!/bin/bash
# Objective suspend test: the device sleeps on an RTC alarm while we watch it
# from outside. If it really sleeps, the network must go away and come back.
set -uo pipefail
H=192.168.86.33
SSH="ssh -i $HOME/.ssh/duo_key -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$H"

echo "=== before: $(ping -c1 -W2 $H >/dev/null 2>&1 && echo reachable || echo unreachable)"
echo "=== arming rtcwake for 15s"
$SSH 'rtcwake -m mem -s 15; echo rtcwake_rc=$?' 2>&1 | tail -3 &

# watch from outside for 60s
for i in $(seq 1 60); do
    if ping -c1 -W1 $H >/dev/null 2>&1; then s=up; else s=DOWN; fi
    echo "$(date +%H:%M:%S) $s"
    sleep 1
done
wait 2>/dev/null || true
