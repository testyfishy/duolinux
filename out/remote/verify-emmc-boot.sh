#!/bin/sh
# Post-migration verification: we are running from the eMMC and nothing is broken.
set -u

echo "=== root device"
findmnt -no SOURCE,FSTYPE,OPTIONS /
lsblk -o NAME,SIZE,PARTLABEL,LABEL,MOUNTPOINT | sed -n '1,12p'
echo "media present: $(ls /dev/mmcblk* | tr '\n' ' ')"

echo "=== boot health"
uptime
systemd-analyze time 2>/dev/null | head -3
echo "system state: $(systemctl is-system-running 2>&1)"
echo "failed units: $(systemctl --failed --no-legend 2>/dev/null | wc -l)"
systemctl --failed --no-legend 2>/dev/null | head -6

echo "=== duo-init's own account of this boot"
sed -n '1,12p' /boot/duo-boot.log 2>/dev/null || echo "no /boot/duo-boot.log"

echo "=== services"
for s in ssh NetworkManager inputplumber duo-lid duo-fan duo-mouse duo-brightness-guard; do
    printf '%-22s %s\n' "$s" "$(systemctl is-active "$s" 2>&1)"
done
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active duo-backkey plasma-plasmashell' 2>&1 | paste -sd' ' -

echo "=== pointer mapping"
timeout 10 busctl call org.shadowblip.InputPlumber /org/shadowblip/InputPlumber/CompositeDevice0 \
    org.freedesktop.DBus.Properties Get ss org.shadowblip.Input.CompositeDevice ProfilePath 2>&1 | head -2
timeout 10 inputplumber device 0 targets list 2>&1 | grep -E "mouse|keyboard|ds5"

echo "=== InputPlumber idle cost"
P=$(pgrep -x inputplumber | head -1)
sleep 20
top -H -b -d 15 -n 2 -p "$P" 2>/dev/null | awk '/^top -/{n++} n==2' | sed -n '6,10p'
python3 - "$P" <<'PY'
import os, sys, time
pid = sys.argv[1]; base = f"/proc/{pid}/task"
def snap():
    out = {}
    for tid in os.listdir(base):
        try:
            name = open(f"{base}/{tid}/comm").read().strip()
            v = 0
            for line in open(f"{base}/{tid}/status"):
                if line.startswith("voluntary_ctxt_switches"):
                    v = int(line.split()[1])
            out[tid] = (name, v)
        except OSError:
            pass
    return out
a = snap(); time.sleep(5); b = snap()
rows = sorted(((b[t][1] - a.get(t, b[t])[1], b[t][0]) for t in b), reverse=True)
print("wakeups/s total:", round(sum(r[0] for r in rows) / 5, 1))
for d, n in rows[:4]:
    print(f"  {d/5:7.1f}  {n}")
PY

echo "=== machine idle"
top -b -d 15 -n 2 2>/dev/null | awk '/^top -/{n++} n==2' | sed -n '3,4p'

echo "=== disk: eMMC root, read-only"
fio --name=rand4k --filename=/dev/mmcblk1p89 --rw=randread --bs=4k --iodepth=1 \
    --direct=1 --ioengine=libaio --time_based --runtime=10 --readonly \
    --output-format=json 2>/dev/null | python3 -c "
import json,sys
r=json.load(sys.stdin)['jobs'][0]['read']
print(f'4K QD1: {r[\"iops\"]:.0f} IOPS, avg {r[\"clat_ns\"][\"mean\"]/1e6:.2f} ms, p99 {r[\"clat_ns\"][\"percentile\"][\"99.000000\"]/1e6:.2f} ms')"
fio --name=seq --filename=/dev/mmcblk1p89 --rw=read --bs=128k --iodepth=4 \
    --direct=1 --ioengine=libaio --time_based --runtime=10 --readonly \
    --output-format=json 2>/dev/null | python3 -c "
import json,sys
r=json.load(sys.stdin)['jobs'][0]['read']
print(f'128K seq: {r[\"bw\"]/1024:.1f} MiB/s')"

echo "=== filesystem health"
df -h / | tail -1
echo "fstab: $(grep -v '^#' /etc/fstab | tr '\n' ' ')"
