#!/bin/bash
# Interactive password reset that SHOWS what is typed, so it can be checked on
# screen before it is committed. Run as root; the password never leaves the device.
set -u
clear
echo "==================================================================="
echo " Set a new password for the 'duo' account"
echo " What you type is displayed, so you can check it before saving."
echo "==================================================================="
echo
while :; do
    printf 'New password: '
    IFS= read -r p1
    printf 'Type it again: '
    IFS= read -r p2
    if [ -z "$p1" ]; then
        echo "Empty password is not allowed. Try again."
        continue
    fi
    if [ "$p1" != "$p2" ]; then
        echo "The two entries do not match. Start again."
        echo
        continue
    fi
    printf 'duo:%s\n' "$p1" | chpasswd
    echo
    echo "Saved. Password for 'duo' is now: $p1"
    echo "(screen clears in 10 seconds)"
    sleep 10
    clear
    echo "Password set. You can close this window."
    break
done
