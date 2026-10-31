#!/bin/bash
# Sample the TX macro registers physically while a capture stream is running.
# Bit 0 of the DMIC control registers does not latch when written, so it is a
# status bit; if it means "clock running" it must go high during a stream.
set -u
P=/opt/duo-stt/venv/bin/python
DUO="XDG_RUNTIME_DIR=/run/user/1000"

echo "=== idle"
$P /tmp/pmem.py r 0xa460000 1
$P /tmp/pmem.py r 0xa4600c0 2

echo "=== starting a 6 s capture"
su - duo -c "$DUO timeout -s INT 6 pw-record --rate 48000 --channels 1 --format s16 /tmp/stat.wav" >/dev/null 2>&1 &
sleep 1.5

echo "=== during capture (5 samples, 0.4 s apart)"
for i in 1 2 3 4 5; do
    printf '  run%d: mclkctl=%s  dmic0=%s  dmic1=%s\n' "$i" \
        "$($P /tmp/pmem.py r 0xa460000 | awk '{print $3}')" \
        "$($P /tmp/pmem.py r 0xa4600c0 | awk '{print $3}')" \
        "$($P /tmp/pmem.py r 0xa4600c4 | awk '{print $3}')"
    sleep 0.4
done

wait
echo "=== after"
$P /tmp/pmem.py r 0xa460000 1
$P /tmp/pmem.py r 0xa4600c0 2
