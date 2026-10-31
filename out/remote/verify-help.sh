#!/bin/bash
set -u
echo "=== service"
systemctl show duo-padhotkeys -p ActiveState -p SubState -p NRestarts -p ExecMainStartTimestamp
echo "=== journal (any traceback?)"
journalctl -u duo-padhotkeys -n 20 --no-pager 2>&1 | tail -12
echo "=== python syntax"
python3 -m py_compile /usr/local/bin/padhotkeys && echo "compiles clean"
echo "=== help script"
sh -n /usr/local/bin/duo-help && echo "duo-help syntax ok"
echo "=== help renders? (needs the session env)"
S=$(ls /run/user/1000/sway-ipc.*.sock | head -1)
timeout 3 su - duo -c "SWAYSOCK=$S XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 /usr/local/bin/duo-help" >/dev/null 2>&1; echo "duo-help exit=$?"
