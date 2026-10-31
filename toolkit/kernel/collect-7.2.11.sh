#!/bin/bash
# Collect everything needed before the 7.2.11 + netfilter build, including whether
# the ROCKNIX SM6115 patches still apply to 7.2.11.
set -uo pipefail
W=${W:-$HOME/rocknix-nf}; mkdir -p "$W"; cd "$W"
echo "=== host"
echo "gcc: $(aarch64-linux-gnu-gcc --version 2>/dev/null | head -1)"
echo "nproc: $(nproc)  mem: $(free -g | awk '/Mem:/{print $2}')G  disk: $(df -h "$W" | awk 'NR==2{print $4}') free"

[ -f linux-7.2.11.tar.xz ] || curl -fsSLO https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.2.11.tar.xz
rm -rf linux-7.2.11 && tar xf linux-7.2.11.tar.xz
echo "=== tree"
make -s -C linux-7.2.11 kernelversion

P=$(find "$W/distribution/projects/ROCKNIX/devices/SM6115/patches/linux" -name '*.patch' 2>/dev/null | sort)
echo "=== patches: $(echo "$P" | grep -c . ) files"
fail=0
for p in $P; do
    if ! ( cd linux-7.2.11 && patch -p1 --dry-run -s -f < "$p" >/dev/null 2>&1 ); then
        echo "FAIL $(basename "$p")"; fail=$((fail+1))
    fi
done
echo "patches failing on 7.2.11: $fail"

echo "=== defconfig candidates"
find "$W/distribution/projects/ROCKNIX/devices/SM6115" -name 'linux*.conf' 2>/dev/null | head -5
echo "=== source pkg ref"
sed -n '/SM6115/,+30p' "$W/distribution/projects/ROCKNIX/packages/linux/package.mk" 2>/dev/null | grep -E 'PKG_VERSION|PKG_URL|LINUX' | head -5
echo "=== our config"
grep -cE '^CONFIG_' "$W/device.config" 2>/dev/null
