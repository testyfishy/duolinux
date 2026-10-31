#!/bin/bash
# Regenerate 0003 from the build tree after dropping the mouse needs_poll change.
set -euo pipefail

SRC="$HOME/duo-build/inputplumber/src"
OUT="/mnt/c/Users/HTPC-Aran/Documents/Default Project/duolinux/out/inputplumber-fork/0003-needs-poll.patch"
BASE=https://raw.githubusercontent.com/ShadowBlip/InputPlumber/v0.82.0

cd "$SRC"
: > /tmp/0003.new
for f in src/input/target/mod.rs src/input/target/keyboard.rs src/input/target/mouse.rs; do
    curl -fsSL "$BASE/$f" -o "/tmp/$(basename "$f").orig"
    diff -u "/tmp/$(basename "$f").orig" "$f" >> /tmp/0003.new || true
done

python3 - "$OUT" <<'PY'
import pathlib, sys
raw = pathlib.Path("/tmp/0003.new").read_text().splitlines()
out = []
for line in raw:
    if line.startswith("--- "):
        out.append("--- a/src/input/target/" + line.split()[1].split("/")[-1])
    elif line.startswith("+++ "):
        out.append("+++ b/src/input/target/" + line.split()[1].split("/")[-1])
    else:
        out.append(line)
path = pathlib.Path(sys.argv[1])
path.write_text("\n".join(out).rstrip("\n") + "\n")
print("wrote", path.name, len(path.read_bytes()), "bytes")
PY

echo "=== files touched by the patch:"
grep -E "^(\+\+\+|---) " "$OUT"
echo "=== needs_poll occurrences:"
grep -c "needs_poll" "$OUT" || true
