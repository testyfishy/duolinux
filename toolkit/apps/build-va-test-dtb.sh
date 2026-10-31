#!/bin/bash
# Build a test DTB from the *vendor* blob that adds the VA capture backend and
# the DMIC sample rate, without touching the boot partition.
#
# Loaded via kexec, so a bad tree costs one automatic reboot, not a rescue.
set -uo pipefail
REPO="/mnt/c/Users/HTPC-Aran/Documents/Default Project/duolinux"
SRC=$REPO/out/kernel/sm6125-retroid-pocket-duo-lite.dtb
OUT=$HOME/rocknix-nf/dtb-va-test.dtb

dtc -I dtb -O dts -o /tmp/va-vendor.dts "$SRC" 2>/dev/null

echo "=== phandles we need"
grep -n -B3 "phandle" /tmp/va-vendor.dts | grep -E "service@4 \{|service@7 \{|service@8 \{|codec@a4a0000 \{|phandle =" | head -20

echo
echo "=== sound node children (to copy the mm3 link shape)"
sed -n '/mm3-dai-link {/,/};/p' /tmp/va-vendor.dts | head -12
