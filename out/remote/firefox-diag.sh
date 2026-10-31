#!/bin/bash
# Work out why Firefox fails on this box.
set -u
echo "=== crash reports:"
ls -t /home/duo/.mozilla/firefox/*/minidumps 2>/dev/null | head -3
find /home/duo/.mozilla -name "*.extra" -newermt "-2 hours" 2>/dev/null | head -3

echo "=== running firefox:"
ps -eo pid,etime,rss,cmd | grep -i firefox | grep -v grep | head -5

echo "=== launch and capture stderr (10 s):"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 timeout 10 firefox-esr --new-window about:blank' 2>&1 | tail -25
echo "exit=$?"

echo "=== kernel version / sandbox bits:"
uname -r
cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo "(no userns sysctl)"
zcat /proc/config.gz 2>/dev/null | grep -E "CONFIG_SECCOMP=|CONFIG_USER_NS=" || echo "(no /proc/config.gz)"
