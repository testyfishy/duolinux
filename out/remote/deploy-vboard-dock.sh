#!/bin/bash
# Deploy the dock patch and restart vboard.
set -u
export DEBIAN_FRONTEND=noninteractive
apt-get -o Acquire::ForceIPv4=true install -y --no-install-recommends gir1.2-gtklayershell-0.1 2>&1 | tail -2

install -m 644 /tmp/vb-window.py /usr/share/vboard/vboard/window.py
install -m 644 /tmp/vb-app.py    /usr/share/vboard/vboard/app.py
python3 -c "import ast,sys; [ast.parse(open(p).read()) for p in ('/usr/share/vboard/vboard/window.py','/usr/share/vboard/vboard/app.py')]; print('syntax ok')"

# the layer surface positions itself; drop the geometry forcing from the rule
python3 - <<'PY'
import pathlib
p = pathlib.Path("/etc/xdg/kwinrulesrc")
keep = []
for line in p.read_text().splitlines():
    key = line.split("=")[0].strip()
    if key in {"position", "positionrule", "size", "sizerule", "noborder", "noborderrule"}:
        continue
    keep.append(line)
p.write_text("\n".join(keep) + "\n")
print("rule simplified")
PY

su - duo -c 'pkill -f "python3 /usr/bin/vboard"; sleep 1'
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 setsid vboard >/tmp/vboard.log 2>&1 < /dev/null &'
sleep 9
echo "=== running:"; pgrep -af "python3 /usr/bin/vboard" | head -2
echo "=== log:"; tail -6 /tmp/vboard.log
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 spectacle -b -n -o /tmp/vb3.png' 2>&1 | tail -1
