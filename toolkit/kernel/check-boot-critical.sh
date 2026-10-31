#!/bin/bash
# Compare a candidate build config against the RUNNING kernel config.
#
# The initrd carries no modules, so every symbol needed to reach the rootfs must
# stay built-in: any =y symbol that becomes =m or unset is a no-boot bug.
#
# usage: check-boot-critical.sh [new .config] [module tree]
set -uo pipefail
W=$HOME/rocknix-nf
NEW=${1:-$W/port/repo/.config}
MODS=${2:-$W/stage-7.2.11/lib/modules/7.2.11-nf}
RUN=$W/run.config
KEY=/mnt/c/path/to/duolinux/out/duo_ssh_key

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

crit = [k for k in run if run[k] == "y" and (
        k.startswith(("CONFIG_MMC", "CONFIG_SDHCI", "CONFIG_EXT4", "CONFIG_BLK_DEV", "CONFIG_VFAT",
                      "CONFIG_NLS", "CONFIG_PINCTRL", "CONFIG_REGULATOR", "CONFIG_CLK", "CONFIG_DRM_MSM",
                      "CONFIG_QCOM", "CONFIG_PHY", "CONFIG_INTERCONNECT", "CONFIG_DEVTMPFS", "CONFIG_TMPFS",
                      "CONFIG_PROC_FS", "CONFIG_SYSFS", "CONFIG_PRINTK")))]
bad = [(k, run[k], new.get(k, "unset")) for k in crit if new.get(k) != "y"]
print(f"boot-critical =y symbols checked: {len(crit)}, downgraded: {len(bad)}")
for k, a, b in bad[:40]:
    print(f"  {k}: running {a} -> new {b}")

# display path must keep its method (=y/=m) or a working panel can vanish
disp = [k for k in run if any(t in k for t in ("DRM_PANEL", "DRM_MSM", "DRM_DSI", "BACKLIGHT",
                                               "DRM_BRIDGE", "PHY_QCOM", "DRM_DISPLAY"))]
chg = [(k, run[k], new.get(k, "unset")) for k in disp if new.get(k) != run[k]]
print(f"display symbols checked: {len(disp)}, changed: {len(chg)}")
for k, a, b in chg[:25]:
    print(f"  {k}: {a} -> {b}")
PY

echo "=== module tree"
[ -d "$MODS" ] && echo "modules: $(find "$MODS" -name '*.ko' | wc -l)" || echo "  (not staged yet)"
echo "=== vermagic"
f=$(find "$MODS" -name 'nf_tables.ko' | head -1)
[ -n "$f" ] && strings "$f" | grep -m1 vermagic || echo "  (no nf_tables.ko yet)"
echo "=== kernel version string"
zcat "$W/KERNEL-7.2.11-nf" 2>/dev/null | strings | grep -m1 "Linux version" || echo "  (not built yet)"
