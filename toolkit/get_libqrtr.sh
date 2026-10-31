#!/bin/bash
S=/mnt/rnx/SYSTEM
D="/mnt/c/Users/HTPC-Aran/Documents/Default Project/duolinux/out/rnx-port/extract"
mkdir -p "$D"
unsquashfs -d "$D" "$S" usr/lib/libqrtr.so.1.2 2>&1 | tail -3
ls -l "$D/usr/lib/libqrtr.so.1.2"
file "$D/usr/lib/libqrtr.so.1.2"
