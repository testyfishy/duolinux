#!/system/bin/sh
# Minimal ABL flash: no reporting, no functions, works in the runner env.
# Writes the ROCKNIX SM6115 ABL to both slots and flushes.
ELF=/sdcard/Download/duolinux/abl_signed-SM6115.elf
dd if="$ELF" of=/dev/block/by-name/abl_a bs=4096 conv=fsync
dd if="$ELF" of=/dev/block/by-name/abl_a bs=4096 conv=fsync
dd if="$ELF" of=/dev/block/by-name/abl_b bs=4096 conv=fsync
sync
