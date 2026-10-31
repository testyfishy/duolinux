#!/usr/bin/env python3
"""Fetch arm64 Debian .debs for the Qualcomm Wi-Fi userspace and unpack them
into the overlay tree, so the device gets them with no network.

Run in WSL:  python3 fetch_debs.py <overlay_dir>
"""
from __future__ import annotations

import lzma
import pathlib
import subprocess
import sys
import urllib.request

PKGS = ["rmtfs", "pd-mapper", "tqftpserv", "libqrtr-glib0", "qrtr-tools"]
INDEX = "https://deb.debian.org/debian/dists/trixie/main/binary-arm64/Packages.xz"
BASE = "https://deb.debian.org/debian/"
CACHE = pathlib.Path("/tmp/duodebs")


def main() -> int:
    overlay = pathlib.Path(sys.argv[1])
    CACHE.mkdir(parents=True, exist_ok=True)

    idx = CACHE / "Packages.xz"
    if not idx.exists():
        print("downloading package index...")
        urllib.request.urlretrieve(INDEX, idx)
    text = lzma.decompress(idx.read_bytes()).decode("utf-8", "replace")

    wanted = {}
    for stanza in text.split("\n\n"):
        lines = stanza.splitlines()
        name = next((l.split(": ", 1)[1] for l in lines if l.startswith("Package: ")), None)
        if name in PKGS:
            fn = next((l.split(": ", 1)[1] for l in lines if l.startswith("Filename: ")), None)
            if fn:
                wanted[name] = fn

    print("found:", sorted(wanted))
    missing = [p for p in PKGS if p not in wanted]
    if missing:
        print("WARNING missing from index:", missing)

    for name, fn in wanted.items():
        deb = CACHE / pathlib.Path(fn).name
        if not deb.exists():
            print(f"downloading {name}: {fn}")
            urllib.request.urlretrieve(BASE + fn, deb)
        subprocess.run(["dpkg-deb", "-x", str(deb), str(overlay)], check=True)
        print(f"unpacked {name}")

    # Show what units and binaries appeared.
    for sub in ("etc/systemd/system", "lib/systemd/system", "usr/bin", "usr/sbin", "usr/lib"):
        d = overlay / sub
        if d.is_dir():
            names = sorted(p.name for p in d.iterdir() if p.is_file())
            interesting = [n for n in names if any(k in n.lower() for k in
                                                   ("rmtfs", "pd-mapper", "tqftpserv", "qrtr", "rmtfs"))]
            print(f"{sub}: {interesting}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
