#!/bin/sh
# Why did it suspend with the lid open on AC, and what modes are the panels in?
set -u

echo "=== restore inputplumber targets"
timeout 15 inputplumber device 0 targets set keyboard mouse ds5 2>&1 | head -3
timeout 10 inputplumber device 0 targets list 2>&1 | head -10

echo "=== suspend/resume history this boot"
journalctl -b --no-pager 2>/dev/null | grep -iE "systemd-logind.*(lid|suspend|sleep)|Entering sleep|suspend entry|PM: suspend|Reached target Sleep|PowerDevil.*(suspend|sleep)|idle" | tail -25

echo "=== logind configuration"
cat /etc/systemd/logind.conf 2>/dev/null | grep -vE "^#|^$"
ls /etc/systemd/logind.conf.d/ 2>/dev/null && cat /etc/systemd/logind.conf.d/* 2>/dev/null
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 loginctl show-user duo' 2>/dev/null | grep -iE "idle|inhibit"

echo "=== powerdevil profiles"
cat /home/duo/.config/powerdevilrc 2>/dev/null | head -60

echo "=== power supplies"
for d in /sys/class/power_supply/*/; do
    echo "$(basename "$d"): type=$(cat "$d/type" 2>/dev/null) status=$(cat "$d/status" 2>/dev/null) capacity=$(cat "$d/capacity" 2>/dev/null)"
done

echo "=== lid daemon"
systemctl status duo-lid --no-pager 2>&1 | head -6
journalctl -u duo-lid -n 8 --no-pager 2>&1 | tail -8

echo "=== display modes"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 kscreen-doctor -o' 2>&1 | head -60
