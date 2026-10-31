DuoLinux — Retroid Pocket Duo Lite
==================================

Files:
  duolinux-duol.img       7.5 GiB SD-card image (GPT: ROCKNIX + STORAGE)
  boot-duolinux-duol.img  34 MiB Android boot image for a non-destructive test
  SHA256SUMS              checksums
  kernel/                 Image, DTB and modules used in the image

Test without writing anything:
  .\duo.ps1 boot

Write to a microSD (16 GB or larger):
  .\duo.ps1 install --disk <n> --yes

Or without a card reader, push it to the device:
  .\duo.ps1 install --via-adb --with-abl

Read docs/BOOT.md before flashing the ABL. The flash script backs up abl_a/abl_b
to /sdcard/Download/duolinux/ first. Copy those backups off the device.
