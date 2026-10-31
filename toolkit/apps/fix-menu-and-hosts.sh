#!/bin/sh
# 1) drop Moonlight's duplicate host entry
# 2) add the missing Tailscale menu entry
# 3) rebuild KDE's application database
set -u
CONF="/home/duo/.var/app/com.moonlight_stream.Moonlight/config/Moonlight Game Streaming Project/Moonlight.conf"

echo "=== hosts before"
grep -E "^[0-9]+\\\\hostname=" "$CONF"

# keep the lowest-numbered entry for each hostname
python3 - "$CONF" <<'PY'
import re, sys
p = sys.argv[1]
lines = open(p).read().splitlines()
seen = set()
out = []
for ln in lines:
    m = re.match(r'^(\d+)\\(hostname|srvcert|manual|localhost|customname|uuid)=', ln)
    if m:
        idx, key = m.group(1), m.group(2)
        if key == 'hostname' and ln.split('=', 1)[1] in seen:
            continue          # duplicate host: skip this index's keys
        if key == 'hostname':
            seen.add(ln.split('=', 1)[1])
    out.append(ln)
# second pass: remove keys belonging to skipped indices
keep = set()
for ln in out:
    m = re.match(r'^(\d+)\\hostname=', ln)
    if m:
        keep.add(m.group(1))
final = [ln for ln in out if not re.match(r'^(\d+)\\', ln) or re.match(r'^(\d+)\\', ln).group(1) in keep]
open(p, 'w').write('\n'.join(final) + '\n')
print("kept indices:", sorted(keep))
PY

echo "=== hosts after"
grep -E "^[0-9]+\\\\hostname=" "$CONF"

echo
echo "=== Tailscale menu entry"
mkdir -p /home/duo/.local/share/applications
cat > /home/duo/.local/share/applications/duo-tailscale.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Tailscale
Comment=Open the Tailscale tray indicator
Exec=/usr/bin/tailscale systray
Icon=network-vpn
Terminal=false
Categories=Network;RemoteAccess;
Keywords=tailscale;vpn;mesh;
EOF

# Moonlight already has a flatpak-exported entry; make sure it is visible
grep -l "NoDisplay=true" /var/lib/flatpak/exports/share/applications/com.moonlight_stream.Moonlight.desktop 2>/dev/null \
    && echo "  moonlight entry is marked NoDisplay" || echo "  moonlight entry is visible"

chown -R duo:duo /home/duo/.local/share/applications
update-desktop-database /home/duo/.local/share/applications 2>/dev/null || true

echo
echo "=== rebuild KDE menu database"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 kbuildsycoca6 --noincremental' 2>&1 | tail -3
echo "  done"
