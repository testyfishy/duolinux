#!/bin/bash
# Replace duo-lid with upstream PowerDevil config.
#
# PowerDevil holds handle-lid-switch but suppresses its own action because the
# DP-1 panel is seen as an external monitor. Upstream has a switch for that:
# inhibitLidActionWhenExternalMonitorPresent. Turning it off and setting the lid
# action to Sleep means KDE itself suspends, and our daemon is not needed.
set -u
U='su - duo -c'
CFG=/home/duo/.config/powerdevilrc
cp -p "$CFG" "/tmp/powerdevilrc.bak.$(date +%H%M%S)"

for profile in AC Battery LowBattery; do
    $U "XDG_RUNTIME_DIR=/run/user/1000 kwriteconfig6 --file powerdevilrc \
        --group $profile --key inhibitLidActionWhenExternalMonitorPresent false" 2>/dev/null
    $U "XDG_RUNTIME_DIR=/run/user/1000 kwriteconfig6 --file powerdevilrc \
        --group $profile --key LidAction --key action 1" 2>/dev/null
done

echo "=== resulting config"
grep -A2 -iE "\[AC\]\[LidAction\]|\[AC\]\[General\]|inhibitLid" "$CFG" 2>/dev/null | head -20
echo "--- raw grep:"
grep -iE "inhibitLid|LidAction" "$CFG" | head -10

echo
echo "=== restart powerdevil so it rereads the config"
$U 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user restart plasma-powerdevil' 2>&1 | head -2
sleep 3
echo "  powerdevil: $(su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active plasma-powerdevil' 2>/dev/null)"

echo
echo "=== stop our lid daemon (rollback: systemctl enable --now duo-lid)"
systemctl disable --now duo-lid 2>&1 | tail -2
echo "  duo-lid: $(systemctl is-active duo-lid 2>/dev/null) / $(systemctl is-enabled duo-lid 2>/dev/null)"

echo
echo "=== inhibitors now"
systemd-inhibit --list 2>/dev/null | grep -iE "lid|powerdevil" | head -3
