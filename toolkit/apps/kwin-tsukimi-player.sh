#!/bin/bash
# Tsukimi's player is an mpv window. Send it fullscreen to the top panel (DSI-1)
# by default, while leaving Tsukimi's library UI where it is.
set -u
CFG=/home/duo/.config/kwinrulesrc
cp -p "$CFG" "/tmp/kwinrulesrc.bak.$(date +%H%M%S)"

python3 - "$CFG" <<'PY'
import io, re, sys
p = sys.argv[1]
text = io.open(p).read()
lines = text.splitlines()

# drop any previous version of this rule
out, skip = [], False
for ln in lines:
    if ln.strip().startswith('[') and ln.strip() != '[duo-tsukimi-player]':
        skip = False
    if ln.strip() == '[duo-tsukimi-player]':
        skip = True
        continue
    if not skip:
        out.append(ln)

# rebuild [General] count/rules
rules = []
count = 0
new = []
for ln in out:
    s = ln.strip()
    if s.startswith('count='):
        continue
    if s.startswith('rules='):
        rules = [r for r in s.split('=', 1)[1].split(',') if r]
        continue
    new.append(ln)
for name in ('duo-maximize-all', 'desktop-skip-taskbar', 'duo-moonlight'):
    if name not in rules:
        rules.append(name)
if 'duo-tsukimi-player' not in rules:
    rules.append('duo-tsukimi-player')
count = len(rules)

# write [General] at the top
body = [l for l in new if l.strip() != '[General]']
final = ['[General]', f'count={count}', 'rules=' + ','.join(rules), ''] + body

final += [
    '[duo-tsukimi-player]',
    'Description=Tsukimi mpv player fullscreen on the top panel',
    'wmclass=mpv',
    'wmclassmatch=2',
    'types=1',
    'typesrule=2',
    'fullscreen=true',
    'fullscreenrule=2',
    'screen=0',
    'screenrule=2',
]
io.open(p, 'w').write('\n'.join(final).strip() + '\n')
print(f"rules: {', '.join(rules)}")
PY

chown duo:duo "$CFG"
echo "=== rule"
grep -A9 "duo-tsukimi-player" "$CFG" | sed 's/^/  /'

echo
echo "=== reload kwin"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 qdbus6 org.kde.KWin /KWin reconfigure' 2>&1 | head -2
