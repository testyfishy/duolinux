#!/bin/sh
# Read-only comparison: microSD (rootfs) vs eMMC (Android userdata).
#
# Every test passes --readonly so nothing is written to either device, and the
# eMMC is never mounted. Direct I/O avoids the page cache to show device speed.
set -u

DEBIAN_FRONTEND=noninteractive apt-get install -y fio >/tmp/fio-apt.log 2>&1
echo "fio: $(command -v fio)"

SD=/dev/mmcblk0p2
EMMC=/dev/mmcblk1p87

run() {
    dev="$1"; label="$2"; rw="$3"; bs="$4"; qd="$5"; nj="$6"
    fio --name="$label" --filename="$dev" --rw="$rw" --bs="$bs" \
        --iodepth="$qd" --numjobs="$nj" --direct=1 --ioengine=libaio \
        --time_based --runtime=15 --ramp_time=3 --readonly --randrepeat=1 \
        --group_reporting --output-format=json --output="/tmp/fio-$label.json" \
        >/dev/null 2>&1
    python3 - "$label" "/tmp/fio-$label.json" <<'PY'
import json, sys
label, path = sys.argv[1], sys.argv[2]
try:
    d = json.load(open(path))
    r = d["jobs"][0]["read"]
    lat = r["clat_ns"]
    print(f"{label:24s} iops={r['iops']:8.1f}  bw={r['bw']/1024:7.1f} MiB/s  "
          f"avg={lat['mean']/1e6:6.2f} ms  p99={lat['percentile']['99.000000']/1e6:7.2f} ms")
except Exception as e:
    print(f"{label:24s} failed: {e}")
PY
}

echo "=== microSD (rootfs) $SD"
run "$SD" "sd-rand4k-qd1"    randread 4k   1  1
run "$SD" "sd-rand4k-qd32"   randread 4k   32 1
run "$SD" "sd-rand64k-qd1"   randread 64k  1  1
run "$SD" "sd-seq128k-qd4"   read     128k 4  1

echo "=== eMMC (android userdata) $EMMC"
run "$EMMC" "emmc-rand4k-qd1"  randread 4k   1  1
run "$EMMC" "emmc-rand4k-qd32" randread 4k   32 1
run "$EMMC" "emmc-rand64k-qd1" randread 64k  1  1
run "$EMMC" "emmc-seq128k-qd4" read     128k 4  1

echo "=== device queue limits"
for d in mmcblk0 mmcblk1; do
    echo "$d: $(cat /sys/block/$d/queue/nr_requests) nr_requests, sched=$(cat /sys/block/$d/queue/scheduler 2>/dev/null)"
done
