#!/bin/bash
set -u
install -m 755 /tmp/duo-fan /usr/local/bin/duo-fan
install -m 755 /tmp/duo-fan-settings /usr/local/bin/duo-fan-settings
mkdir -p /etc/duo
[ -f /etc/duo/fan-profile ] || printf 'balanced\n' > /etc/duo/fan-profile

python3 -m py_compile /usr/local/bin/duo-fan && echo "fan daemon compiles"
sh -n /usr/local/bin/duo-fan-settings && echo "settings script ok"

# add the entry to the Settings menu if missing
if ! grep -q 'Fan profile' /usr/local/bin/duo-settings; then
    python3 - <<'PY'
import pathlib
p = pathlib.Path("/usr/local/bin/duo-settings")
t = p.read_text()
t = t.replace("    'Mouse speed' \\", "    'Mouse speed' \\\n    'Fan profile' \\")
t = t.replace("    'Mouse speed')       exec /usr/local/bin/duo-mouse-settings ;;",
              "    'Mouse speed')       exec /usr/local/bin/duo-mouse-settings ;;\n"
              "    'Fan profile')       exec /usr/local/bin/duo-fan-settings ;;")
p.write_text(t)
print("settings menu updated")
PY
fi

systemctl restart duo-fan
sleep 6
echo "=== profile: $(cat /etc/duo/fan-profile)"
journalctl -u duo-fan -n 4 --no-pager | tail -3
grep -n "Fan profile" /usr/local/bin/duo-settings

echo "=== plasma install:"
pgrep -f apt-get >/dev/null && echo "  still running" || tail -3 /var/log/plasma-install.log
