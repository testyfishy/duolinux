#!/bin/sh
# zram per the reviewed plan: generator, ram/2, zstd, swappiness 150, page-cluster 0,
# MGLRU on with min_ttl_ms=1000, zswap off.
set -u

echo "=== before"
cat /proc/swaps
zramctl 2>/dev/null | head -3
echo "comp_algorithm: $(cat /sys/block/zram0/comp_algorithm 2>/dev/null)"
dpkg -l 2>/dev/null | awk '/zram|zswap/ {print $2, $3}'
echo "zswap: $(cat /sys/module/zswap/parameters/enabled 2>/dev/null)"
echo "mglru: $(cat /sys/kernel/mm/lru_gen/enabled 2>/dev/null || echo missing)"

echo "=== units/files that create zram today"
systemctl list-unit-files 2>/dev/null | grep -i zram
ls /etc/systemd/zram-generator.conf* 2>/dev/null
cat /etc/default/zramswap 2>/dev/null | head -5
grep -rs zram /etc/fstab /etc/udev/rules.d 2>/dev/null | head -3

# Remove the older mechanism if present, so nothing fights the generator.
if dpkg -s zram-tools >/dev/null 2>&1; then
    systemctl disable --now zramswap 2>/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get purge -y zram-tools >/tmp/purge-zram.log 2>&1
    echo "purged zram-tools"
fi

DEBIAN_FRONTEND=noninteractive apt-get install -y systemd-zram-generator >/tmp/zg.log 2>&1
echo "generator: $(dpkg -s systemd-zram-generator 2>/dev/null | awk '/^Version/{print $2}')"

cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF

cat > /etc/sysctl.d/99-zram.conf <<'EOF'
vm.swappiness = 150
vm.page-cluster = 0
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
EOF

cat > /etc/tmpfiles.d/mglru.conf <<'EOF'
w- /sys/kernel/mm/lru_gen/enabled    - - - - y
w- /sys/kernel/mm/lru_gen/min_ttl_ms - - - - 1000
EOF

# zswap would compress pages that then land on a compressed block device.
echo "options zswap enabled=0" > /etc/modprobe.d/zswap-off.conf
echo 0 > /sys/module/zswap/parameters/enabled 2>/dev/null || true

echo "=== apply"
swapoff /dev/zram0 2>/dev/null || true
zramctl --reset /dev/zram0 2>/dev/null || true
systemctl daemon-reload
systemctl start systemd-zram-setup@zram0.service 2>&1 | tail -2
sysctl --system >/dev/null 2>&1
systemd-tmpfiles --create /etc/tmpfiles.d/mglru.conf 2>/dev/null || true

echo "=== after"
zramctl 2>/dev/null | head -3
swapon --show
sysctl vm.swappiness vm.page-cluster vm.watermark_boost_factor vm.watermark_scale_factor 2>/dev/null | tail -4
echo "mglru: $(cat /sys/kernel/mm/lru_gen/enabled 2>/dev/null) min_ttl_ms: $(cat /sys/kernel/mm/lru_gen/min_ttl_ms 2>/dev/null)"
echo "zswap: $(cat /sys/module/zswap/parameters/enabled 2>/dev/null)"
echo "unit: $(systemctl is-active systemd-zram-setup@zram0.service 2>&1)"
