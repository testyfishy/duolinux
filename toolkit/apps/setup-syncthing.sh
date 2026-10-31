#!/bin/sh
# Enable the upstream Syncthing package as a user service and report how to use it.
set -u
systemctl enable --now syncthing@duo.service 2>&1 | tail -2
sleep 6

echo "=== service"
echo "  enabled: $(systemctl is-enabled syncthing@duo.service)"
echo "  active:  $(systemctl is-active syncthing@duo.service)"
echo "  version: $(syncthing --version 2>/dev/null | head -1)"

echo
echo "=== config"
CFG=/home/duo/.local/state/syncthing/config.xml
if [ -f "$CFG" ]; then
    echo "  gui: $(grep -o '<address>[^<]*</address>' "$CFG" | head -1)"
    echo "  device id: $(syncthing --device-id 2>/dev/null || su - duo -c 'syncthing --device-id' 2>/dev/null)"
else
    echo "  config not created yet"
fi

echo
echo "=== reachable?"
curl -s -o /dev/null -w "  http://127.0.0.1:8384 -> %{http_code}\n" http://127.0.0.1:8384/ 2>/dev/null || echo "  not answering yet"

echo
echo "=== memory"
for p in $(pgrep -x syncthing 2>/dev/null); do
    echo "  pid $p pss=$(awk '/^Pss:/{print $2}' /proc/$p/smaps_rollup 2>/dev/null) kB"
done
