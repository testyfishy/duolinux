#!/bin/bash
set -e
S=/mnt/rnx/SYSTEM
OUTDIR="/mnt/c/path/to/duolinux/out/rnx-port/files"
mkdir -p "$OUTDIR"
echo "=== extracting with -cat"
unsquashfs -cat "$S" usr/lib/libqrtr.so.1.2 > "$OUTDIR/libqrtr.so.1.2"
ls -l "$OUTDIR/libqrtr.so.1.2"
file "$OUTDIR/libqrtr.so.1.2"
echo "=== also grab their pd-mapper unit + retroid-duolite firmware as files"
unsquashfs -cat "$S" usr/lib/systemd/system/pd-mapper.service > "$OUTDIR/pd-mapper.service"
ls -l "$OUTDIR"
