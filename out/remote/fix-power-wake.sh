#!/bin/bash
# Make the handheld wake properly: the power key must not shut the machine down,
# the screen may blank but nothing should suspend, and Home wakes the display
# and opens the launcher.
set -u

echo "=== 1. logind: power key must not power off"
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/duo.conf <<'EOF'
# Handheld: a short press of the power button must not shut the device down
# (it is the only "wake" reflex a user has). Long press still powers off.
[Login]
HandlePowerKey=ignore
HandlePowerKeyLongPress=poweroff
HandleSuspendKey=ignore
IdleAction=ignore
EOF
systemctl restart systemd-logind 2>/dev/null || true
sleep 1
loginctl show-session "$(loginctl | awk '/duo/ {print $1; exit}')" -p Id 2>/dev/null | head -1

echo "=== 2. powerdevil: blank the screen, never suspend"
su - duo -c '
XDG_RUNTIME_DIR=/run/user/1000
for g in AC Battery; do
  kwriteconfig6 --file powerdevilrc --group "$g" --group SuspendSession --key idleTime 0
  kwriteconfig6 --file powerdevilrc --group "$g" --group DPMSControl --key idleTime 300000
  kwriteconfig6 --file powerdevilrc --group "$g" --group DimDisplay --key idleTime 0
  kwriteconfig6 --file powerdevilrc --group "$g" --group PowerButtonAction --key action 0
done
'
grep -A2 "SuspendSession" /home/duo/.config/powerdevilrc 2>/dev/null | head -6

echo "=== 3. make sure powerdevil is actually running (battery applet needs it)"
if ! pgrep -f org_kde_powerdevil >/dev/null; then
    su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 setsid /usr/lib/aarch64-linux-gnu/libexec/org_kde_powerdevil >/tmp/powerdevil.log 2>&1 < /dev/null &'
fi
sleep 3
echo "powerdevil: $(pgrep -c org_kde_powerdevil 2>/dev/null || echo 0)"
tail -2 /tmp/powerdevil.log 2>/dev/null

echo "=== 4. kscreen-doctor available for the wake-on-Home path?"
command -v kscreen-doctor || echo "MISSING"
