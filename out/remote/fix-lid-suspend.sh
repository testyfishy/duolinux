#!/bin/sh
# Make duo-lid the only thing that suspends on the lid.
set -u

install -m 755 /tmp/duo-lid /usr/local/bin/duo-lid
systemctl restart duo-lid
sleep 2
echo "duo-lid: $(systemctl is-active duo-lid)"
journalctl -u duo-lid -n 3 --no-pager 2>&1 | tail -3

python3 - <<'PY'
import pathlib

path = pathlib.Path("/home/duo/.config/powerdevilrc")
text = path.read_text() if path.exists() else ""
lines = text.splitlines()

for profile in ("AC", "Battery", "LowBattery"):
    header = f"[{profile}][LidAction]"
    if header in lines:
        index = lines.index(header)
        replaced = False
        for i in range(index + 1, len(lines)):
            if lines[i].startswith("["):
                break
            if lines[i].startswith("action="):
                lines[i] = "action=0"
                replaced = True
        if not replaced:
            lines.insert(index + 1, "action=0")
    else:
        lines += ["", header, "action=0"]

path.write_text("\n".join(lines).rstrip("\n") + "\n")
print("powerdevilrc lid actions set to 0 (do nothing)")
PY

chown duo:duo /home/duo/.config/powerdevilrc
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user restart plasma-powerdevil' 2>&1
sleep 5
echo "powerdevil: $(su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active plasma-powerdevil' 2>&1)"
for g in AC Battery; do
    echo "$g lid action: $(su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 kreadconfig6 --file powerdevilrc --group $g --group LidAction --key action" 2>&1)"
done
echo "=== inhibitors now:"
systemd-inhibit --list 2>/dev/null | grep -iE "powerdevil|WHO" | head -3
