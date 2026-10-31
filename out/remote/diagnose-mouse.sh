#!/bin/sh
# Which mouse path is broken: the touchpad, the stick-as-pointer target, or a daemon.
set -u

echo "=== mouse-related services"
for s in duo-mouse duo-backkey duo-controller inputplumber; do
    printf '%s: %s\n' "$s" "$(systemctl is-active "$s" 2>&1)"
done
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active duo-backkey' 2>&1

echo "=== mouse mode config"
cat /etc/duo/mouse-mode 2>/dev/null || echo "no /etc/duo/mouse-mode"
cat /etc/duo/scroll-source 2>/dev/null || echo "no /etc/duo/scroll-source"

echo "=== input devices with names"
grep -E "^N: Name=|^H: Handlers=" /proc/bus/input/devices | paste - - | sed 's/  */ /g' | grep -iE "mouse|touch|duo|plumber|gamepad" | head -12

echo "=== InputPlumber targets and their nodes"
for t in mouse keyboard ds5; do
    echo "-- $t"
    timeout 6 inputplumber device 0 target "$t" info 2>&1 | head -6
done

echo "=== recent inputplumber warnings/errors"
journalctl -u inputplumber --since '-15 min' --no-pager 2>&1 | grep -iE "error|warn|mouse|target|fail" | tail -12

echo "=== duo-mouse journal"
journalctl -u duo-mouse -n 10 --no-pager 2>&1 | tail -10

echo "=== pointer device state"
for d in /dev/input/event*; do
    name=$(cat /sys/class/input/$(basename "$d")/device/name 2>/dev/null)
    case "$name" in
        *Mouse*|*mouse*|*Touchpad*|*touchpad*) echo "$d: $name" ;;
    esac
done
