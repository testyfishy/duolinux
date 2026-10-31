#!/bin/sh
# Force Moonlight's window to fullscreen via a KWin rule, so it can never be
# larger than the screen again. Then reload KWin.
set -u
CFG=/home/duo/.config/kwinrulesrc

echo "=== current rules file"
[ -f "$CFG" ] && head -20 "$CFG" || echo "  (none)"

python3 - "$CFG" <<'PY'
import io, os, sys
p = sys.argv[1]
text = io.open(p).read() if os.path.exists(p) else ""
lines = [l for l in text.splitlines()]

def group_of(line):
    return line.strip()[1:-1] if line.strip().startswith("[") else None

# remove any previous Moonlight rule we may have written
out, skip = [], False
for ln in lines:
    g = group_of(ln)
    if g is not None:
        skip = False
    if ln.strip() == "Description=Moonlight fullscreen (duo)":
        # drop the group header just written
        while out and out[-1].strip().startswith("[") is False and out[-1].strip() == "":
            out.pop()
        if out and out[-1].strip().startswith("["):
            out.pop()
        skip = True
        continue
    if skip and group_of(ln) is not None:
        skip = False
    if not skip:
        out.append(ln)

# ensure [General] exists and count is incremented
body = "\n".join(out)
count = 0
for ln in out:
    if ln.strip().startswith("count="):
        try: count = int(ln.split("=")[1])
        except ValueError: count = 0
count += 1
idx = count

# rewrite [General]
new = []
for ln in out:
    if ln.strip().startswith("count="):
        new.append(f"count={count}")
    else:
        new.append(ln)
if not any(l.strip().startswith("count=") for l in new):
    new = ["[General]", f"count={count}"] + [l for l in new if l.strip() != "[General]"]

new.append("")
new.append(f"[{idx}]")
new.append("Description=Moonlight fullscreen (duo)")
new.append("wmclass=com.moonlight_stream.Moonlight")
new.append("wmclasscomplete=false")
new.append("wmclassmatch=1")
new.append("types=1")
new.append("fullscreen=true")
new.append("fullscreenrule=2")
new.append("")

io.open(p, "w").write("\n".join(new).strip() + "\n")
print(f"rule written as group [{idx}]")
PY

chown duo:duo "$CFG"
echo "=== rule now"
grep -A9 "Moonlight fullscreen" "$CFG"

echo
echo "=== reload KWin"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 qdbus6 org.kde.KWin /KWin reconfigure' 2>&1 | head -3
