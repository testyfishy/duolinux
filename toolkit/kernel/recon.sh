#!/bin/bash
# Kernel recon: gather the facts the build needs, without assumptions.
# Stage 1 of the 7.2.0-nf job (netfilter for Tailscale).
set -uo pipefail
WORK=${WORK:-$HOME/rocknix-nf}; mkdir -p "$WORK"; cd "$WORK"
KEY=/mnt/c/path/to/duolinux/out/duo_ssh_key
SSH="ssh -i '$KEY' -o BatchMode=yes -o StrictHostKeyChecking=no root@192.168.1.33"

echo "=== 1. device kernel facts"
eval $SSH "'uname -r; cat /proc/version'"
eval $SSH "'zcat /proc/config.gz'" > device.config
echo "config bytes: $(wc -c < device.config)"
grep -E '^CONFIG_(INITRAMFS_SOURCE|MODULES|MODULE_COMPRESS|LOCALVERSION|IPV6|ZRAM|LRU_GEN|PSI|ENERGY_MODEL)=' device.config || true

echo "=== 2. boot partition"
eval $SSH "'B=\$(findfs LABEL=ROCKNIX); mkdir -p /mnt/fat; mount \$B /mnt/fat 2>/dev/null; df -h /mnt/fat | tail -1; ls -l /mnt/fat | head -12; head -c 64 /mnt/fat/KERNEL | xxd | sed -n 4p'"

echo "=== 3. initrd contents (modules?)"
eval $SSH "'cd /tmp && rm -rf ird && mkdir ird && cd ird && (zcat /mnt/fat/initrd.img 2>/dev/null || cat /mnt/fat/initrd.img) | cpio -it 2>/dev/null | grep -cE \"\\.ko\$|lib/modules\" ; ls'" | tail -12

echo "=== 4. ROCKNIX source layout"
[ -d distribution ] || git clone --depth 1 -q https://github.com/ROCKNIX/distribution distribution
cd distribution
echo "-- kernel package files:"
find . -path '*SM6115*' -name 'package.mk' 2>/dev/null | head -3
grep -rn 'PKG_VERSION' --include=package.mk packages/kernel/linux projects/ROCKNIX/packages/linux 2>/dev/null | head -5
echo "-- patch dirs:"
find . -path '*SM6115*' -type d -name 'linux' 2>/dev/null | head -5
find . -type d -path '*patches*' -name linux 2>/dev/null | head -5
echo "-- linux source ref:"
grep -rn 'PKG_URL\|PKG_SOURCE\|PKG_TARBALL' packages/kernel/linux/package.mk projects/ROCKNIX/packages/linux/package.mk 2>/dev/null | head -5
