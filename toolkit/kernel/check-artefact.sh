#!/bin/bash
# Final artefact checks for KERNEL-nf + modules tarball.
set -uo pipefail
W=$HOME/rocknix-nf
T=$W/modules-7.2.0-nf.tgz
echo "modules in tarball: $(tar -tzf "$T" | grep -c '\.ko$')"
echo "modules.dep entries: $(tar -xzOf "$T" lib/modules/7.2.0-nf/modules.dep 2>/dev/null | wc -l)"
echo "modules.alias entries: $(tar -xzOf "$T" lib/modules/7.2.0-nf/modules.alias 2>/dev/null | wc -l)"
f=$(tar -tzf "$T" | grep -m1 'net/netfilter/nf_tables.ko$')
echo "nf_tables: $f"
tar -xzOf "$T" "$f" 2>/dev/null | strings | grep -m1 vermagic
echo "kernel: $(stat -c %s "$W/KERNEL-nf") bytes"
zcat "$W/KERNEL-nf" | strings | grep -m1 "Linux version"
echo "netfilter modules: $(tar -tzf "$T" | grep -c 'netfilter/.*\.ko$')"
echo "ip_tables present: $(tar -tzf "$T" | grep -c 'ip_tables\.ko$')"
echo "nft_compat present: $(tar -tzf "$T" | grep -c 'nft_compat\.ko$')"
