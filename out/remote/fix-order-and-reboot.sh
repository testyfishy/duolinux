#!/bin/sh
set -u
A=/home/duo/.config/plasma-org.kde.plasma.desktop-appletsrc
cp -a "$A" /root/appletsrc.before-order
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user stop plasma-plasmashell'
sleep 2
# Windows-style: launcher, tasks, spacer, tray, clock
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 3 --group General --key AppletOrder "27;24;7;29;19"'
echo "order now: $(su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 kreadconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 3 --group General --key AppletOrder')"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user start plasma-plasmashell'
sleep 20
systemctl reboot
