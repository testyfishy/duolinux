#!/bin/bash
# Compare the TX macro register block idle vs during a capture stream.
# Registers that change are what the driver programs for a stream; DMIC-related
# registers that never change are the ones nobody enables.
set -u
P=/opt/duo-stt/venv/bin/python
DUO="XDG_RUNTIME_DIR=/run/user/1000"

dump() {
    "$P" - <<'PY'
import mmap, os, struct
fd = os.open("/dev/mem", os.O_RDONLY | os.O_SYNC)
base = 0xa460000
m = mmap.mmap(fd, 0x1000, mmap.MAP_SHARED, mmap.PROT_READ, offset=base)
for off in range(0, 0x140, 4):
    v = struct.unpack("<I", m[off:off+4])[0]
    print("%03x %08x" % (off, v))
m.close(); os.close(fd)
PY
}

dump > /tmp/tx_idle.txt

su - duo -c "$DUO timeout -s INT 8 pw-record --rate 48000 --channels 1 --format s16 /tmp/dump.wav" >/dev/null 2>&1 &
sleep 2
dump > /tmp/tx_active.txt
wait

echo "=== registers that differ during a stream"
join /tmp/tx_idle.txt /tmp/tx_active.txt | awk '$2 != $3 {printf "  0x%s  idle=%s  active=%s\n", $1, $2, $3}'

echo
echo "=== DMIC-related registers (0x0b0-0x0ff) idle vs active"
join /tmp/tx_idle.txt /tmp/tx_active.txt | awk '$1 >= "0b0" && $1 <= "0ff" {printf "  0x%s  idle=%s  active=%s\n", $1, $2, $3}'
