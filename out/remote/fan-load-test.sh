#!/bin/bash
# Load the CPU the way a game would, then watch the fan follow without hunting.
set -u
echo "=== load for 60 s"
for i in 1 2 3 4; do (timeout 60 sh -c 'while :; do :; done' &) ; done
sleep 62
echo "=== cooling for 45 s"
sleep 45
echo "=== fan log during the whole test"
journalctl -u duo-fan --since "-2 min" --no-pager | tail -40
echo
echo "=== changes in pwm (should be a smooth staircase, not a flicker)"
journalctl -u duo-fan --since "-2 min" --no-pager |
  grep -o "pwm [0-9]*" | awk '{print $2}' |
  awk 'NR==1{p=$1; print p; next} {if ($1!=p) {print $1; p=$1}}'
