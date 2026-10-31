#!/usr/bin/env python3
"""Pin every fuzzel dialog to the top panel (DSI-1) and detect DP-1 before Sway."""
import pathlib
import re

FILES = ["duo-wifi", "duo-help", "duo-settings", "duo-apps", "duo-scale"]

for name in FILES:
    p = pathlib.Path("/tmp/ui") / name
    if not p.exists():
        continue
    t = p.read_text()
    if "--output" in t:
        print(f"{name}: already pinned")
        continue
    # every invocation of fuzzel gets the output flag
    t2 = re.sub(r"\bfuzzel\b(?! --output)", "fuzzel --output DSI-1", t)
    p.write_text(t2, encoding="utf-8", newline="\n")
    print(f"{name}: pinned to DSI-1")

# Early detect in the session script
s = pathlib.Path("/tmp/ui/duo-session")
if s.exists():
    t = s.read_text()
    if "duo-bottom-detect" not in t:
        t = t.replace(
            "while :; do",
            "# Make sure the bottom panel exists before the compositor starts.\n"
            "sudo -n /usr/local/bin/duo-bottom-detect >/dev/null 2>&1 || true\n\n"
            "while :; do",
            1,
        )
        s.write_text(t, encoding="utf-8", newline="\n")
        print("duo-session: early DP-1 detect added")
    else:
        print("duo-session: already has the detect")
