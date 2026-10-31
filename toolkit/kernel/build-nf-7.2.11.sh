#!/bin/bash
# Build 7.2.11-nf from the ported branch.
#
# Same config recipe as the working 7.2.0-nf kernel: tree defconfig + netfilter
# deltas, INITRAMFS_SOURCE cleared (external initrd), LOCALVERSION=-nf.
# Output: KERNEL-7.2.11-nf (gzip), modules-7.2.11-nf.tgz, config-7.2.11-nf.
set -euo pipefail
W=$HOME/rocknix-nf
P=$W/port/repo
K=$W/distribution
BR=rk-7.2.11-full
S=$W/stage-7.2.11
LOG=$W/build-7.2.11.log
: > "$LOG"
exec >>"$LOG" 2>&1

cd "$P"
echo "=== tree: $(git rev-parse --short $BR) on $BR"

make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- mrproper
cp "$K/projects/ROCKNIX/devices/SM6115/linux/linux.aarch64.conf" .config
C="scripts/config --file .config"
$C -e NETFILTER -e NETFILTER_ADVANCED -e IP_ADVANCED_ROUTER -e IP_MULTIPLE_TABLES -e IPV6_MULTIPLE_TABLES \
   -e TUN -e NF_TABLES -e NF_TABLES_INET -e NF_TABLES_IPV4 -e NF_TABLES_IPV6 \
   -e NF_CONNTRACK -e NF_NAT -e NETFILTER_XTABLES -e IP_NF_IPTABLES -e IP_NF_FILTER -e IP_NF_NAT -e IP_NF_MANGLE \
   -m IP6_NF_IPTABLES -m IP6_NF_FILTER -m IP6_NF_MANGLE \
   -m NFT_NAT -m NFT_MASQ -m NFT_CT -m NFT_COMPAT -m NFT_REJECT \
   -m NETFILTER_XT_MARK -m NETFILTER_XT_MATCH_MARK -m NETFILTER_XT_MATCH_COMMENT -m NETFILTER_XT_MATCH_CONNTRACK \
   -m NETFILTER_XT_TARGET_MASQUERADE -m NETFILTER_XT_MATCH_CONNMARK -m NETFILTER_XT_TARGET_CONNMARK \
   -e LRU_GEN -e PSI -e ENERGY_MODEL -m ZRAM -m CRYPTO_ZSTD
$C --set-str INITRAMFS_SOURCE "" -d LOCALVERSION_AUTO -d MODULE_SIG_FORCE -e IKCONFIG -e IKCONFIG_PROC
make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig

miss=0
for s in NETFILTER NF_TABLES NFT_COMPAT NETFILTER_XT_TARGET_MASQUERADE TUN IP_MULTIPLE_TABLES \
         IPV6_MULTIPLE_TABLES LRU_GEN PSI ENERGY_MODEL ZRAM CRYPTO_ZSTD IKCONFIG IKCONFIG_PROC; do
    grep -qE "^CONFIG_${s}=[ym]" .config || { echo "MISSING $s"; miss=$((miss+1)); }
done
[ "$miss" = 0 ] || { echo "$miss symbols missing"; exit 1; }
rel=$(make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION=-nf kernelrelease)
echo "kernelrelease: $rel"
[ "$rel" = "7.2.11-nf" ] || { echo "bad kernelrelease"; exit 1; }

echo "=== building"
make -j"$(nproc)" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION=-nf Image.gz modules dtbs

echo "=== staging modules"
rm -rf "$S"
make -j"$(nproc)" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION=-nf \
     INSTALL_MOD_PATH="$S" INSTALL_MOD_STRIP=1 modules_install
rm -f "$S"/lib/modules/7.2.11-nf/build "$S"/lib/modules/7.2.11-nf/source

cp arch/arm64/boot/Image.gz "$W/KERNEL-7.2.11-nf"
cp .config "$W/config-7.2.11-nf"
tar -C "$S" -czf "$W/modules-7.2.11-nf.tgz" lib/modules/7.2.11-nf

echo "=== artefact"
ls -l "$W/KERNEL-7.2.11-nf" "$W/modules-7.2.11-nf.tgz"
echo "modules: $(find "$S/lib/modules/7.2.11-nf" -name '*.ko' | wc -l)"
zcat "$W/KERNEL-7.2.11-nf" | strings | grep -m1 "Linux version"
