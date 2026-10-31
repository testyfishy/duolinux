#!/bin/bash
# Maximise every window type that can be resized: Normal (1) + Utility (32) +
# Dialog (128) = 161. Menus, tooltips and notifications are left alone, since
# maximising those would break them.
set -u
CFG=/home/duo/.config/kwinrulesrc
cp -p "$CFG" "/tmp/kwinrulesrc.bak.$(date +%H%M%S)"

python3 - "$CFG" <<'PY'
import io, re, sys
p = sys.argv[1]
text = io.open(p).read().splitlines()
out, inrule = [], False
for ln in text:
    s = ln.strip()
    if s.startswith('['):
        inrule = (s == '[duo-maximize-all]')
        out.append(ln)
        continue
    if inrule and (s.startswith('types=') or s.startswith('typesrule=')):
        continue
    if inrule and s.startswith('maximize'):
        continue
    if inrule and s.startswith('Description='):
        out.append('Description=Maximise every resizable window')
        continue
    out.append(ln)
    if inrule and s.startswith('Description='):
        pass

# ensure the keys exist right after the rule header
final, inside = [], False
for ln in out:
    final.append(ln)
    if ln.strip() == '[duo-maximize-all]':
        inside = True
        final += [
            'types=161',
            'typesrule=2',
            'maximizehoriz=true',
            'maximizehorizrule=2',
            'maximizevert=true',
            'maximizevertrule=2',
        ]
        continue
    if inside and ln.strip().startswith('['):
        inside = False
io.open(p, 'w').write('\n'.join(final).strip() + '\n')
PY

chown duo:duo "$CFG"
echo "=== rule now"
sed -n '/\[duo-maximize-all\]/,/^\[/p' "$CFG" | head -8 | sed 's/^/  /'

echo
echo "=== reload"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 qdbus6 org.kde.KWin /KWin reconfigure' 2>&1 | head -2
