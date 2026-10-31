#!/bin/sh
set -u
echo "=== what KDE reads for the key"
for g in AC Battery LowBattery; do
    v=$(su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 kreadconfig6 --file powerdevilrc --group $g --key inhibitLidActionWhenExternalMonitorPresent" 2>/dev/null)
    a=$(su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 kreadconfig6 --file powerdevilrc --group $g --subgroup LidAction --key action" 2>/dev/null)
    echo "  $g: inhibit='$v'  LidAction='$a'"
done

echo
echo "=== which power profile is active"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 qdbus6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement org.kde.Solid.PowerManagement.currentProfile' 2>&1 | head -2

echo
echo "=== powerdevil startup lines (any config complaint)"
journalctl -b 0 --no-pager 2>/dev/null | grep -i powerdevil | grep -iE "config|profile|lid|error|warn" | tail -8

echo
echo "=== is an external output actually reported?"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 kscreen-doctor -j' 2>/dev/null \
  | python3 -c 'import json,sys
d=json.load(sys.stdin)
for o in d.get("outputs", []):
    print(f"  {o.get(\"name\")}: enabled={o.get(\"enabled\")} priority={o.get(\"priority\")}")'
