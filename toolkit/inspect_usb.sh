#!/bin/bash
echo "===== USB gadget support in the kernel Image:"
for s in "libcomposite" "usb_f_ncm" "usb_f_acm" "usb_f_rndis" "configfs" "dwc3" "rndis" "gadget"; do
  n=$(strings -a /tmp/KERNEL 2>/dev/null | grep -c -- "$s")
  printf "  %-14s %s\n" "$s" "$n"
done

echo "===== dwc3 dr_mode in the DTB (string scan):"
strings -a /tmp/duo.dtb | grep -i -E "dr_mode|peripheral|otg|dwc3" | sort -u | head -20

echo "===== gadget modules in the rootfs:"
cd "/mnt/c/path/to/duolinux/out" || exit 1
D="duolinux-duol.img?offset=537919488"
debugfs -R "ls /lib/modules/7.2.0/kernel/drivers/usb/gadget" "duolinux-duol.img?offset=537919488" 2>/dev/null
