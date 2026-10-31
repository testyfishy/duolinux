#!/usr/bin/env python3
"""Force LF line endings on every overlay file, and make scripts executable."""
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
changed = []
skipped = []
for p in sorted(root.rglob("*")):
    if not p.is_file():
        continue
    data = p.read_bytes()
    if b"\x00" in data:          # binary: never touch line endings
        skipped.append(str(p.relative_to(root)))
        continue
    if b"\r\n" in data:
        p.write_bytes(data.replace(b"\r\n", b"\n"))
        changed.append(str(p.relative_to(root)))

# ENABLE must end with a newline.
enable = root / "ENABLE"
if enable.exists():
    txt = enable.read_text()
    lines = [ln.strip() for ln in txt.splitlines() if ln.strip()]
    enable.write_text("\n".join(lines) + "\n")

print("CRLF fixed in:", changed if changed else "none")
print("ENABLE:", repr(enable.read_text()) if enable.exists() else "missing")
