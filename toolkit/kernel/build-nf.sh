#!/bin/bash
# Build 7.2.0 from the ROCKNIX SM6115 tree with netfilter, LOCALVERSION=-nf.
# Kernel-only install for the Debian rootfs.
#
# Patch order follows scripts/unpack: package patches first, then device patches
# (PKG_PATCH_DIRS="${LINUX} mainline ${DEVICE} default").
set -euo pipefail
W=$HOME/rocknix-nf; K=$W/distribution; S=$W/src
mkdir -p "$S"
cd "$S"

# 1. source + patches
[ -f linux-7.2.tar.xz ] || curl -fsSLO https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.2.tar.xz
rm -rf linux-7.2
tar xf linux-7.2.tar.xz
cd linux-7.2

PKG_PATCHES=$K/projects/ROCKNIX/packages/linux/patches
DEV_PATCHES=$K/projects/ROCKNIX/devices/SM6115/patches/linux
for dir in "$PKG_PATCHES" "$DEV_PATCHES"; do
    n=$(ls "$dir"/*.patch 2>/dev/null | wc -l || true)
    echo "patching from $dir ($n patches)"
    for p in "$dir"/*.patch; do
        [ -f "$p" ] || continue
        if ! patch -p1 -s -f < "$p"; then
            case "$(basename "$p")" in
                0208-*) echo "SKIP $p (optional DPU tuning)" ;;
                *) echo "PATCH FAIL $p"; exit 1 ;;
            esac
        fi
    done
done
echo "patched tree: $(make -s kernelversion)"

# 2. config from the tree defconfig, netfilter deltas, normalisation
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
$C --set-str INITRAMFS_SOURCE "" -d LOCALVERSION_AUTO -d MODULE_SIG_FORCE
make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig

# 3. verify symbols survived olddefconfig
miss=0
for s in NETFILTER NF_TABLES NFT_COMPAT NETFILTER_XT_TARGET_MASQUERADE TUN IP_MULTIPLE_TABLES \
         IPV6_MULTIPLE_TABLES LRU_GEN PSI ENERGY_MODEL ZRAM CRYPTO_ZSTD IKCONFIG; do
    grep -qE "^CONFIG_${s}=[ym]" .config || { echo "MISSING $s"; miss=$((miss+1)); }
done
[ "$miss" = 0 ] || { echo "$miss symbols missing"; exit 1; }
rel=$(make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION=-nf kernelrelease)
[ "$rel" = "7.2.0-nf" ] || { echo "bad kernelrelease: $rel"; exit 1; }

# 4. build + stage
N=$(nproc)
make -j"$N" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION=-nf Image.gz modules dtbs
rm -rf "$W/stage"
make -j"$N" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION=-nf \
     INSTALL_MOD_PATH="$W/stage" INSTALL_MOD_STRIP=1 modules_install
rm -f "$W/stage/lib/modules/7.2.0-nf/build" "$W/stage/lib/modules/7.2.0-nf/source"
tar -C "$W/stage" -czf "$W/modules-7.2.0-nf.tgz" lib/modules/7.2.0-nf
cp arch/arm64/boot/Image.gz "$W/KERNEL-nf"
cp .config "$W/config-7.2.0-nf"
echo "=== artefact"
ls -l "$W/KERNEL-nf" "$W/modules-7.2.0-nf.tgz"
modinfo -F vermagic "$W/stage/lib/modules/7.2.0-nf/kernel/net/netfilter/nf_tables.ko" 2>/dev/null || true
grep -c '\.ko' "$W/stage/lib/modules/7.2.0-nf/modules.dep" 2>/dev/null || true
