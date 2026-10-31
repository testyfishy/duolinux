#!/bin/bash
set -uo pipefail
K=$HOME/.ssh/duo_key
R="/mnt/c/Users/user/Documents/Default Project/duolinux/out/device-config"
scp -q -i "$K" -o StrictHostKeyChecking=no \
    root@192.168.1.33:/home/duo/.config/powerdevilrc "$R/powerdevilrc" \
    && echo "powerdevilrc saved"
ls -l "$R" | sed 's/^/  /'
