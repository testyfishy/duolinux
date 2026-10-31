#!/bin/bash
# Pull the Android boot/dtbo/vendor_boot images and extract every FDT in them.
#
# The stock Android works with the built-in microphone, so its device tree is
# the authority on how the mic is wired (input, regulator, GPIO). The images are
# still on mmcblk1 and readable from Debian.
set -uo pipefail
KEY=$HOME/.ssh/duo_key
H=root@192.168.86.33
SSH="ssh -i $KEY -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
SCP="scp -q -i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
OUT=$HOME/android-images
mkdir -p "$OUT"

for p in boot_a dtbo_a vendor_boot_a; do
    if [ -s "$OUT/$p.img" ]; then echo "  $p.img already pulled"; continue; fi
    echo "=== pulling $p"
    $SSH "$H" "dd if=/dev/disk/by-partlabel/$p of=/tmp/$p.img bs=1M status=none && sha256sum /tmp/$p.img" || { echo "  failed"; continue; }
    $SCP "$H:/tmp/$p.img" "$OUT/$p.img"
    $SSH "$H" "rm -f /tmp/$p.img"
done

ls -l "$OUT" | sed 's/^/  /'

echo
echo "=== finding FDTs"
python3 - "$OUT" <<'PY'
import os, struct, sys

d = sys.argv[1]
MAGIC = b"\xd0\x0d\xfe\xed"
for name in sorted(os.listdir(d)):
    if not name.endswith(".img"):
        continue
    p = os.path.join(d, name)
    data = open(p, "rb").read()
    offs = []
    i = data.find(MAGIC)
    while i >= 0:
        # a plausible FDT also carries its total size at offset 4
        if i + 8 <= len(data):
            size, = struct.unpack(">I", data[i+4:i+8])
            if 32 <= size <= len(data) - i:
                offs.append((i, size))
                i = data.find(MAGIC, i + size)
                continue
        i = data.find(MAGIC, i + 1)
    print("%s: %d bytes, %d FDT(s)" % (name, len(data), len(offs)))
    outdir = os.path.join(d, name[:-4])
    os.makedirs(outdir, exist_ok=True)
    for n, (o, s) in enumerate(offs):
        fn = os.path.join(outdir, "dtb-%02d.dtb" % n)
        open(fn, "wb").write(data[o:o+s])
        print("   %-14s offset 0x%08x size %6d" % (os.path.basename(fn), o, s))
PY

echo
echo "=== decompiling"
for dtb in "$OUT"/*/dtb-*.dtb; do
    [ -f "$dtb" ] || continue
    dtc -I dtb -O dts -o "${dtb%.dtb}.dts" "$dtb" 2>/dev/null || rm -f "${dtb%.dtb}.dts"
done
echo "  .dts files: $(ls "$OUT"/*/*.dts 2>/dev/null | wc -l)"

echo
echo "=== nodes mentioning the microphone"
grep -ilE "dmic|micbias|mic-bias|audio-routing|adsp|q6afe" "$OUT"/*/*.dts 2>/dev/null | sed 's/^/  /'
