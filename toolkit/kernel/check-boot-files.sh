#!/bin/bash
# Read-only integrity + difference check on the eMMC boot files.
# A truncated copy or a kernel that differs from v2 in more than the codec
# would change the diagnosis.
set -uo pipefail
mount -o ro /dev/mmcblk1p88 /mnt/emmc 2>/dev/null || true

echo "=== gzip integrity"
for k in KERNEL KERNEL.dmic KERNEL.721nf; do
    printf '  %-14s ' "$k"
    if zcat "/mnt/emmc/$k" > "/tmp/$k.raw" 2>/dev/null; then
        echo "ok, Image $(stat -c %s "/tmp/$k.raw") bytes"
    else
        echo "GZIP FAILED"
    fi
done

echo
echo "=== DTB identity"
for d in /mnt/emmc/dtbs/qcom/sm6125-retroid-pocket-duo-lite.dtb \
         /mnt/emmc/dtbs/qcom/sm6125-retroid-pocket-duo-lite.dtb.dmic; do
    printf '  %-55s %s bytes magic=%s\n' "$(basename "$d")" "$(stat -c %s "$d")" \
        "$(od -An -tx1 -N4 "$d" | tr -d ' \n')"
done

echo
echo "=== how much do the two kernels differ?"
if [ -f /tmp/KERNEL.raw ] && [ -f /tmp/KERNEL.dmic.raw ]; then
    a=/tmp/KERNEL.raw; b=/tmp/KERNEL.dmic.raw
    echo "  sizes: v3=$(stat -c %s $a) v2=$(stat -c %s $b)"
    # compressed payloads differ throughout, so compare the decompressed Images
    # by counting differing 4 KiB blocks
    n=$(cmp -l "$a" "$b" 2>/dev/null | wc -l)
    echo "  differing bytes: $n"
    python3 - "$a" "$b" <<'PY'
import sys
a = open(sys.argv[1], "rb").read()
b = open(sys.argv[2], "rb").read()
n = min(len(a), len(b))
BS = 4096
diff_blocks = [i // BS for i in range(0, n, BS)
               if a[i:i+BS] != b[i:i+BS]]
print("  differing 4 KiB blocks: %d of %d" % (len(diff_blocks), n // BS))
if diff_blocks:
    print("  first block %d (~offset 0x%x), last %d (~0x%x)"
          % (diff_blocks[0], diff_blocks[0]*BS, diff_blocks[-1], diff_blocks[-1]*BS))
PY
fi

echo
echo "=== initrd (unchanged between boots?)"
ls -l --time-style=+%m-%d\ %H:%M /mnt/emmc/initrd.img | sed 's/^/  /'

echo
echo "=== v3 kernel: does it contain the amp symbols?"
strings /tmp/KERNEL.raw 2>/dev/null | grep -c "aw88166" | sed 's/^/  aw88166 strings: /'

umount /mnt/emmc 2>/dev/null
rm -f /tmp/KERNEL.raw /tmp/KERNEL.dmic.raw /tmp/KERNEL.721nf.raw
echo DONE
