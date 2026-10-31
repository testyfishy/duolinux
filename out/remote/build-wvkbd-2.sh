#!/bin/bash
set -u
cd /root/wvkbd-0.15 || exit 1
echo "=== build"
make clean >/dev/null 2>&1
make 2>&1 | tail -15

echo "=== result"
ls -l wvkbd-mobintl 2>/dev/null || { echo "BUILD FAILED"; exit 1; }

echo "=== install"
install -m 755 wvkbd-mobintl /usr/local/bin/wvkbd-mobintl
/usr/local/bin/wvkbd-mobintl --help 2>&1 | grep -i output

echo "=== which binary is used"
command -v wvkbd-mobintl
