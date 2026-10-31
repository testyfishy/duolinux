#!/system/bin/sh
# One-shot: read back the ABL, hash the card, flash the ACTIVE slot (b), re-read it.
#
# Reporting trick: shell redirection is unreliable in this runner, and `settings`
# is unreliable too, but `dd` and `chmod` work. So results are carried by:
#   * files we can pull later  (ablA_now.img, ablB_now.img, ablB_after.img)
#   * empty marker files whose NAME contains the answer (CARDHASH_<sha256>)
#   * STEPn markers proving how far the script got
D=/data/local/tmp
ELF=/sdcard/Download/duolinux/abl_signed-SM6115.elf

rm -f "$D"/CARDHASH_* "$D"/STEP1 "$D"/STEP2 "$D"/STEP3 "$D"/STEP4 "$D"/STEP5 2>/dev/null

dd if=/dev/block/by-name/abl_a of="$D/ablA_now.img" bs=4096 2>/dev/null
dd if=/dev/block/by-name/abl_b of="$D/ablB_now.img" bs=4096 2>/dev/null
chmod 644 "$D/ablA_now.img" "$D/ablB_now.img" 2>/dev/null
dd if=/dev/zero of="$D/STEP1_readback" bs=1 count=0 2>/dev/null

# Hash exactly 15740962 sectors (8,059,372,544 bytes) = 7686 MiB + 34 sectors.
H=$( ( dd if=/dev/block/mmcblk1 bs=1048576 count=7686 2>/dev/null; \
        dd if=/dev/block/mmcblk1 bs=512 skip=15740928 count=34 2>/dev/null ) | sha256sum | awk '{print $1}' )
dd if=/dev/zero of="$D/CARDHASH_$H" bs=1 count=0 2>/dev/null
dd if=/dev/zero of="$D/STEP2_cardhashed" bs=1 count=0 2>/dev/null

# Flash the active slot only (ro.boot.slot_suffix is _b on this unit).
dd if="$ELF" of=/dev/block/by-name/abl_b bs=4096 conv=fsync 2>/dev/null
dd if=/dev/zero of="$D/STEP3_flashed_b_rc_$?" bs=1 count=0 2>/dev/null
sync

dd if=/dev/block/by-name/abl_b of="$D/ablB_after.img" bs=4096 2>/dev/null
chmod 644 "$D/ablB_after.img" 2>/dev/null
dd if=/dev/zero of="$D/STEP4_after_read" bs=1 count=0 2>/dev/null

dd if=/dev/zero of="$D/STEP5_done" bs=1 count=0 2>/dev/null
