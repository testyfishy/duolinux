#!/bin/bash
# Compare the new build config against the RUNNING kernel config, focusing on
# symbols that must stay built-in because the initrd has no modules.
set -uo pipefail
W=$HOME/rocknix-nf
NEW=$W/src/linux-7.2/.config
RUN=$W/run.config
KEY=/mnt/c/Users/HTPC-Aran/Documents/Default\ Project/duolinux/out/duo_ssh_key
if [ ! -s "$RUN" ]; then
    tr -d '\r' < "$KEY" > ~/.ssh/duo_key; chmod 600 ~/.ssh/duo_key
    ssh -i ~/.ssh/duo_key -o BatchMode=yes -o StrictHostKeyChecking=no root@192.168.86.33 'zcat /proc/config.gz' > "$RUN"
fi
echo "run config: $(wc -l < "$RUN") lines, new: $(wc -l < "$NEW") lines"

python3 - "$RUN" "$NEW" <<'PY'
import sys
def load(p):
    d = {}
    for line in open(p, errors="ignore"):
        line = line.strip()
        if line.startswith("CONFIG_") and "=" in line:
            k, v = line.split("=", 1)
            d[k] = v
    return d
run, new = load(sys.argv[1]), load(sys.argv[2])

# Critical: cannot be downgraded to module/unset because the initrd loads no modules.
crit = [k for k in run if run[k] == "y" and (
        k.startswith(("CONFIG_MMC", "CONFIG_SDHCI", "CONFIG_EXT4", "CONFIG_BLK_DEV", "CONFIG_VFAT",
                      "CONFIG_NLS", "CONFIG_PINCTRL", "CONFIG_REGULATOR", "CONFIG_CLK", "CONFIG_DRM_MSM",
                      "CONFIG_QCOM", "CONFIG_PHY", "CONFIG_INTERCONNECT", "CONFIG_DEVTMPFS", "CONFIG_TMPFS",
                      "CONFIG_PROC_FS", "CONFIG_SYSFS", "CONFIG_PRINTK")))]

bad = [(k, run[k], new.get(k, "unset")) for k in crit if new.get(k) != "y"]
print(f"boot-critical =y symbols checked: {len(crit)}, downgraded: {len(bad)}")
for k, a, b in bad[:40]:
    print(f"  {k}: running {a} -> new {b}")
PY

echo "=== module inventory"
tar -tzf "$W/modules-7.2.0-nf.tgz" | grep -c '\.ko$'
echo "running: $(find /lib/modules/7.2.0 -name '*.ko*' 2>/dev/null | wc -l) (on device)"
echo "=== vermagic"
modinfo -F vermagic "$W/stage/lib/modules/7.2.0-nf/kernel/net/netfilter/nf_tables.ko" 2>/dev/null
echo "=== kernel version string"
zcat "$W/KERNEL-nf" | strings | grep -m1 "Linux version"
