#!/bin/bash
set -u
install -m 755 /tmp/duo-osk /usr/local/bin/duo-osk
sh -n /usr/local/bin/duo-osk && echo syntax-ok

# Start it hidden at session start so toggling never moves focus.
if ! grep -q 'duo-osk --init' /etc/sway/config; then
    sed -i 's|^exec_always /usr/local/bin/duo-display|exec_always /usr/local/bin/duo-display\nexec /usr/local/bin/duo-osk --init|' /etc/sway/config
    echo "added duo-osk --init to the sway config"
fi
grep -n 'duo-osk\|duo-display' /etc/sway/config

echo "=== restart the session"
pkill -x sway 2>/dev/null || true
sleep 10
pgrep -a sway | head -2
echo "=== keyboard pre-created hidden?"
pgrep -a wvkbd | cut -c1-100
echo "=== state file (absent = hidden)"
ls -l /run/user/1000/duo-osk.on 2>/dev/null || echo "  hidden (good)"
