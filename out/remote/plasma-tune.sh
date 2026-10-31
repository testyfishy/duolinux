#!/bin/bash
# Apply the handheld-oriented Plasma/KWin defaults in one pass.
# Sources for the choices: Plasma Mobile's envmanager defaults (effects off,
# borderless maximised, empty session), plus what actually matters on an
# Adreno 610 doing a rotated 720p composite over microSD.
set -u
export XDG_RUNTIME_DIR=/run/user/1000
U=duo
as_duo() { su - "$U" -c "XDG_RUNTIME_DIR=/run/user/1000 $*"; }

echo "=== 1. touch -> output via udev (works for any compositor)"
cat > /etc/udev/rules.d/90-touch-output.rules <<'EOF'
# Each touchscreen belongs to one physical panel. libinput exposes this as
# WL_OUTPUT; KWin falls back to it when kcminputrc has no OutputName.
ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="Himax Touchscreen", ENV{WL_OUTPUT}="DSI-1"
ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="generic ft5x06 (a0)", ENV{WL_OUTPUT}="DP-1"
EOF
udevadm control --reload-rules
udevadm trigger --subsystem-match=input --action=change
echo "  rules written"

echo "=== 2. KWin: input method + effects + edges"
as_duo kwriteconfig6 --file kwinrc --group Wayland --key InputMethod /usr/bin/maliit-keyboard
as_duo kwriteconfig6 --file kwinrc --group Windows --key BorderlessMaximizedWindows true
as_duo kwriteconfig6 --file kwinrc --group Windows --key Placement Maximizing
for e in blurEnabled contrastEnabled slidingpopupsEnabled fadingpopupsEnabled \
         scaleEnabled slideEnabled screenedgeEnabled overviewEnabled \
         dimscreenEnabled kwin4_effect_dimscreenEnabled; do
    as_duo kwriteconfig6 --file kwinrc --group Plugins --key "$e" false
done
as_duo kwriteconfig6 --file kwinrc --group ElectricBorders --key TopLeft None
as_duo kwriteconfig6 --file kwinrc --group ElectricBorders --key TopRight None
as_duo kwriteconfig6 --file kwinrc --group ElectricBorders --key BottomLeft None
as_duo kwriteconfig6 --file kwinrc --group ElectricBorders --key BottomRight None
as_duo kwriteconfig6 --file kwinrc --group EdgeBarrier --key EdgeBarrier 0
as_duo kwriteconfig6 --file kwinrc --group EdgeBarrier --key CornerBarrier false

echo "=== 3. no animations, no lock screen, empty session"
as_duo kwriteconfig6 --file kdeglobals --group KDE --key AnimationDurationFactor 0
as_duo kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock false
as_duo kwriteconfig6 --file kscreenlockerrc --group Daemon --key LockOnResume false
as_duo kwriteconfig6 --file ksmserverrc --group General --key loginMode emptySession

echo "=== 4. baloo (file indexer) off - big win on an SD card"
as_duo balooctl6 disable 2>&1 | tail -2

echo "=== 5. desktop folder view: stop the error, use a plain desktop"
install -d -o duo -g duo /home/duo/Desktop
as_duo xdg-user-dirs-update 2>&1 | tail -1

echo "=== 6. make sure DP-1 exists before KWin starts"
systemctl is-enabled duo-bottom-detect.service

echo "=== done; effective values:"
grep -A6 "\[Plugins\]" /home/duo/.config/kwinrc | head -8
grep -A2 "\[Wayland\]" /home/duo/.config/kwinrc | head -4
