#!/bin/bash
# Install a cross-built 7.2.11-nf kernel: Image, modules and the board DTB.
#
# The DTB matters as much as the KERNEL - it is loaded from the FAT boot
# partition (dtbs/qcom/sm6125-retroid-pocket-duo-lite.dtb), not from the kernel
# image, so a device-tree change only takes effect when it is copied there.
#
# Usage: install-nf.sh [--no-reboot]
set -euo pipefail
W=$HOME/rocknix-nf
KEY=$HOME/.ssh/duo_key
H=root@192.168.1.33
SSH="ssh -i $KEY -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
SCP="scp -q -i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
DTB=$W/port/repo/arch/arm64/boot/dts/qcom/sm6125-retroid-pocket-duo-lite.dtb

echo "=== artefacts"
ls -l "$W/KERNEL-7.2.11-nf" "$W/modules-7.2.11-nf.tgz" "$DTB" 2>/dev/null || {
    echo "missing build output; run toolkit/kernel/build-nf-7.2.11.sh" >&2; exit 1; }
echo "  kernel: $(zcat "$W/KERNEL-7.2.11-nf" | strings | grep -m1 "Linux version" || true)"

echo
echo "=== shipping"
$SCP "$W/KERNEL-7.2.11-nf" "$W/modules-7.2.11-nf.tgz" "$DTB" "$H:/tmp/"

echo
echo "=== installing"
$SSH "$H" '
set -e
tar -C / -xzf /tmp/modules-7.2.11-nf.tgz
depmod -a 7.2.11-nf

mount /dev/mmcblk1p88 /mnt/boot
cd /mnt/boot
echo "  dtb target: $(realpath --relative-to=/mnt/boot /mnt/boot/dtbs/qcom/sm6125-retroid-pocket-duo-lite.dtb 2>/dev/null || echo MISSING)"

[ -f KERNEL.dmic ] || cp -p KERNEL KERNEL.dmic
cp /tmp/KERNEL-7.2.11-nf KERNEL

D=dtbs/qcom/sm6125-retroid-pocket-duo-lite.dtb
[ -f "$D.dmic" ] || cp -p "$D" "$D.dmic"
cp /tmp/sm6125-retroid-pocket-duo-lite.dtb "$D"

sync
echo "  KERNEL $(stat -c %s KERNEL)  backup $(stat -c %s KERNEL.dmic)"
echo "  dtb    $(stat -c %s "$D")  backup $(stat -c %s "$D.dmic")"
echo "  dtb strings: $(strings "$D" | grep -c "MIC BIAS1") mic-bias references"
cd /
umount /mnt/boot 2>/dev/null || umount -l /mnt/boot
echo INSTALLED
'

if [ "${1:-}" = "--no-reboot" ]; then
    echo "  (not rebooting)"
    exit 0
fi

echo
echo "=== reboot"
$SSH "$H" 'systemctl reboot' 2>/dev/null || true
sleep 30
for i in $(seq 1 30); do
    $SSH "$H" 'true' 2>/dev/null && { echo "  back after ~$((30 + i * 5))s"; break; }
    sleep 5
done
sleep 8

echo
echo "=== kernel and dtb in use"
$SSH "$H" '
echo "  kernel: $(uname -r)"
echo "  dtb:    $(strings /sys/firmware/fdt 2>/dev/null | grep -c "MIC BIAS1") mic-bias references"
'

echo
echo "=== microphone check (3 s, should show a noise floor, not exact zeros)"
$SSH "$H" '
su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 timeout 3 pw-record --rate 48000 --channels 1 --format s16 /tmp/mic-bias.wav" 2>/dev/null
/opt/duo-stt/venv/bin/python - <<PY
import wave, struct
w = wave.open("/tmp/mic-bias.wav"); n = w.getnframes(); sr = w.getframerate()
d = struct.unpack("<%dh" % n, w.readframes(n))
if not n:
    print("  no samples"); raise SystemExit
rms = (sum(x*x for x in d)/n) ** 0.5
zc = sum(1 for k in range(1, n) if (d[k-1] < 0) != (d[k] < 0))
nz = sum(1 for x in d if x)
print("  %.2fs rms=%.0f peak=%d zc/s=%.0f nonzero=%.1f%%" % (n/sr, rms, max(abs(x) for x in d), zc/(n/sr), 100.0*nz/n))
PY
'
