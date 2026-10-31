DuoLinux ABL folder
===================

This folder is on the FAT ROCKNIX partition of the microSD card.

On the Duo Lite, with the card inserted:

1. Settings -> Handheld Settings -> Advanced -> Run script as root.
2. Browse to this folder on the SD card.
3. Run backup_abl.sh first.
4. Copy abl_a.img and abl_b.img somewhere safe.
5. Run flash_abl.sh.
6. Power off. Hold Volume Down at power-on.
7. Set Boot mode = Linux, Boot source = SD Card, then Start.

If Android will not let you run a script from the SD card, copy this whole
folder to internal storage with the Files app and run it from there.

The card contains no Android data and no internal-storage writes except the
ABL partitions, which are backed up first.
