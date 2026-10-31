#!/bin/bash
set -u
S=/mnt/rnx/SYSTEM

echo "=== ROCKNIX fancontrol config sample"
unsquashfs -cat "$S" usr/config/fancontrol.conf.sample 2>/dev/null | head -40

echo
echo "=== any Duo Lite / retroid specific fan config"
unsquashfs -ll "$S" 2>/dev/null | awk '{print $NF}' | grep -iE 'retroid|duolite' | grep -iE 'fan|quirks' | head -10

echo
echo "=== their fan control autostart script"
unsquashfs -cat "$S" usr/lib/autostart/quirks/platforms/AMD64/020-fan_control 2>/dev/null | head -30
