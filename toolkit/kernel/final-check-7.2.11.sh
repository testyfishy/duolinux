#!/bin/bash
set -uo pipefail
W=$HOME/rocknix-nf
M=$W/stage-7.2.11/lib/modules/7.2.11-nf
echo "vermagic: $(strings "$M/kernel/net/netfilter/nft_compat.ko" | grep -m1 vermagic)"
echo "modules in tree: $(find "$M" -name '*.ko' | wc -l)"
echo "modules.dep: $(wc -l < "$M/modules.dep")"
echo "modules.alias: $(wc -l < "$M/modules.alias")"
echo "modules in tarball: $(tar -tzf "$W/modules-7.2.11-nf.tgz" | grep -c '\.ko$')"
echo "kernel: $(stat -c %s "$W/KERNEL-7.2.11-nf") bytes"
gzip -t "$W/KERNEL-7.2.11-nf" && echo "gzip: valid"
zcat "$W/KERNEL-7.2.11-nf" | strings | grep -m1 "Linux version"
echo "kernelrelease: $(cd "$W/port/repo" && make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION=-nf kernelrelease)"
