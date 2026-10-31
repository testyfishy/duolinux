#!/bin/bash
# Build the uinput-capable wvkbd fork and report any compiler errors verbatim.
set -u
cd /root/wvkbd-0.15 || exit 1
echo "=== files"
ls -l uinput.c uinput.h keyboard.c keyboard.h main.c | awk '{print $5, $9}'

echo "=== build"
make 2>&1 | tail -30

echo "=== result"
if [ -x wvkbd-mobintl ]; then
    ls -l wvkbd-mobintl
    echo "BUILD OK"
else
    echo "BUILD FAILED"
fi
