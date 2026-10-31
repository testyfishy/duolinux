#!/usr/bin/env python3
"""Sanity check: binaries must contain NUL bytes and no CRLF pairs."""
import sys

for p in sys.argv[1:]:
    d = open(p, "rb").read()
    nul = d.count(bytes([0]))
    crlf = d.count(b"\r\n")
    name = p.split("/")[-1]
    verdict = "ok" if nul > 0 and crlf == 0 else "SUSPECT"
    print(f"  {name:14s} size={len(d):7d} nul={nul:6d} crlf={crlf:4d} {verdict}")
