#!/bin/bash
# Install the hysteretic fan controller and the pointer-follows-mouse behaviour
# that makes "scroll where the pointer is" work like Windows.
set -u

install -m 755 /tmp/duo-fan /usr/local/bin/duo-fan
python3 -m py_compile /usr/local/bin/duo-fan && echo "fan compiles"
systemctl restart duo-fan
sleep 4

echo "=== fan now:"
journalctl -u duo-fan -n 6 --no-pager | tail -5

echo "=== window focus: follows mouse (so wheel events go where the pointer is)"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 kwriteconfig6 --file kwinrc --group Windows --key FocusPolicy 1'
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 kwriteconfig6 --file kwinrc --group Windows --key AutoRaise false'
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 kwriteconfig6 --file kwinrc --group Windows --key DelayFocusInterval 0'
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 kwriteconfig6 --file kwinrc --group Windows --key FocusStealingPreventionLevel 0'
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 qdbus6 org.kde.KWin /KWin reconfigure' 2>&1 | tail -1
sleep 2
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 kreadconfig6 --file kwinrc --group Windows --key FocusPolicy'

echo "=== effective KWin focus policy:"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 qdbus6 org.kde.KWin /KWin supportInformation' 2>/dev/null | grep -iE "focus policy|FocusPolicy" | head -3
