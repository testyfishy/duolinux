#!/bin/bash
set -u
CFG=/home/duo/.config/plasma-org.kde.plasma.desktop-appletsrc
echo "=== systemtray applet configuration"
awk '/\[Applets\]\[[0-9]+\]\[Configuration\]/{c=$0} /plugin=org.kde.plasma.systemtray/{print c}' "$CFG" 2>/dev/null | tail -1
python3 - "$CFG" <<'PY'
import configparser, sys, re, io
text = io.open(sys.argv[1], encoding='utf-8', errors='ignore').read()
# find the containment/applet section whose plugin is systemtray
sections = text.split('\n[')
target = None
for s in sections:
    if 'plugin=org.kde.plasma.systemtray' in s:
        # section header is the first line of this chunk
        head = s.split(']', 1)[0]
        target = head
        break
print("  applet section:", target)
for s in sections:
    head = s.split(']', 1)[0]
    if target and head.startswith(target) and 'Configuration' in head:
        print("  ---", head)
        for line in s.split('\n')[1:]:
            if line.strip():
                print("     ", line.strip())
PY

echo
echo "=== panel sections with height/alignment"
grep -E "^\[Containments\]\[[0-9]+\]$|^height=|^plugin=org.kde.panel|^alignment=|^location=" "$CFG" 2>/dev/null | tail -20
