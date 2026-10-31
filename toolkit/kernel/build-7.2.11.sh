#!/bin/bash
# Attempt the 7.2.11 base: 3-way apply the ROCKNIX SM6115 series onto v7.2.11.
# Reports conflicts instead of dying, so we know exactly what needs hand-porting.
set -uo pipefail
W=$HOME/rocknix-nf; G=$W/linux-git; K=$W/distribution
cd "$W"
if [ ! -d "$G/.git" ]; then
    git clone --filter=blob:none --no-checkout -q https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git "$G"
fi
cd "$G"
git fetch -q --depth 1 origin v7.2.11
git checkout -q -f FETCH_HEAD
git clean -qfdx
echo "base: $(make -s kernelversion)"

fail=0
for p in "$K"/projects/ROCKNIX/devices/SM6115/patches/linux/*.patch; do
    if ! git apply -3 --whitespace=nowarn "$p" 2>/dev/null; then
        echo "CONFLICT $(basename "$p")"
        git checkout -q -- . 2>/dev/null
        fail=$((fail+1))
    fi
done
echo "conflicts on 7.2.11: $fail"
if [ "$fail" -eq 0 ]; then
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
    make -j"$(nproc)" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION=-nf Image.gz modules dtbs
    rm -rf "$W/stage-nf211"
    make -j"$(nproc)" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION=-nf \
         INSTALL_MOD_PATH="$W/stage-nf211" INSTALL_MOD_STRIP=1 modules_install
    cp arch/arm64/boot/Image.gz "$W/KERNEL-7.2.11-nf"
    tar -C "$W/stage-nf211" -czf "$W/modules-7.2.11-nf.tgz" lib/modules/7.2.11-nf
    echo "built: $(stat -c %s "$W/KERNEL-7.2.11-nf") bytes"
fi
