#!/bin/bash
set -u
S=/mnt/rnx/SYSTEM
D="/mnt/c/Users/user/Documents/Default Project/duolinux/out/rnx-port/plumber"
mkdir -p "$D"
unsquashfs -cat "$S" usr/bin/inputplumber > "$D/inputplumber" 2>/dev/null
ls -l "$D/inputplumber" 2>/dev/null || { echo "extract failed"; exit 0; }
file "$D/inputplumber"
echo "=== NEEDED"
readelf -d "$D/inputplumber" 2>/dev/null | awk '/NEEDED/{print "  " $5}' | tr -d '[]'
echo "=== interpreter"
readelf -l "$D/inputplumber" 2>/dev/null | awk '/interpreter/{print "  " $NF}' | tr -d ']'
echo "=== size"
du -h "$D/inputplumber"
