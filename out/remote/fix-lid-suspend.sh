#!/bin/bash
# Suspend policy: lid closed sleeps, everything else does not.
# Also hand scrolling over to InputPlumber (the patched build), stopping the
# Python daemon from emitting wheel events as well.
set -u

echo "=== 1. allow suspend again (the mask blocked the lid too)"
systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>&1 | tail -3

echo "=== 2. logind owns the lid; idle never suspends"
cat > /etc/systemd/logind.conf.d/duo.conf <<'EOF'
# Handheld: closing the lid suspends, opening it resumes. Idle never suspends,
# and the power key does not shut the device down.
[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=ignore
HandlePowerKey=ignore
HandlePowerKeyLongPress=poweroff
HandleSuspendKey=ignore
IdleAction=ignore
EOF
systemctl restart systemd-logind 2>/dev/null || true
sleep 1

echo "=== 3. powerdevil must not idle-suspend on its own"
su - duo -c '
for g in AC Battery; do
  kwriteconfig6 --file powerdevilrc --group "$g" --group SuspendSession --key idleTime 0
done
'

echo "=== 4. scrolling now comes from InputPlumber"
printf 'inputplumber\n' > /etc/duo/scroll-source
printf 'wheel\n' > /etc/duo/scroll-source

echo "=== effective lid settings:"
systemd-analyze cat-config systemd/logind.conf 2>/dev/null | grep -E "^HandleLid|^IdleAction" | head -6

echo "=== lid device present:"
grep -c "gpio-keys-lid" /proc/bus/input/devices
