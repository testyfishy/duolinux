#!/bin/bash
# Assemble the v1.0 release assets: kernel + modules + the known-good DTB, and
# the published kernel patch series.
set -euo pipefail

OUT="/mnt/c/Users/user/AppData/Local/Temp/opencode/release"
REPO="/mnt/c/Users/user/Documents/Default Project/duolinux"
W="$HOME/rocknix-nf"

rm -rf "$OUT"
mkdir -p "$OUT"

cp "$W/KERNEL-7.2.11-nf"                  "$OUT/Image.gz"
cp "$W/modules-7.2.11-nf.tgz"             "$OUT/"
cp "$W/dtb-vendor-dmic-fdtput.dtb"        "$OUT/sm6125-retroid-pocket-duo-lite.dtb"

# the known-good tree is the vendor blob with the mic-bias route patched in
tar -C "$OUT" -cJf "$OUT/duolinux-v1.0-kernel-7.2.11-nf.tar.xz" \
    Image.gz modules-7.2.11-nf.tgz sm6125-retroid-pocket-duo-lite.dtb
rm -f "$OUT/Image.gz" "$OUT/modules-7.2.11-nf.tgz" "$OUT/sm6125-retroid-pocket-duo-lite.dtb"

tar -C "$REPO" -cJf "$OUT/duolinux-v1.0-kernel-patches-7.2.11.tar.xz" kernel/patches/7.2.11

cd "$OUT"
sha256sum ./*.tar.xz > SHA256SUMS
ls -l "$OUT" | sed 's/^/  /'
cat SHA256SUMS | sed 's/^/  /'
