#!/bin/sh
# Configure jellyfin-mpv-shim for this device: mpv fullscreen on the top panel,
# software decode (no hardware codec on this SoC), gamepad input enabled.
set -u
APP=com.github.iwalton3.jellyfin-mpv-shim
CFG=/home/duo/.var/app/$APP/config/jellyfin-mpv-shim
mkdir -p "$CFG"

cat > "$CFG/mpv.conf" <<'EOF'
# Software decode: this SoC has no usable hardware codec (Venus lacks its
# clock driver in gcc-sm6125), and 1080p60 H.264 measured at 5x realtime.
hwdec=no
# Keep the compositor out of the video path where possible.
video-sync=display-resample
# Fullscreen on the top panel; the bottom panel keeps the library/UI.
fs=yes
fs-screen-name=DSI-1
# Gamepad support is enabled from the shim settings below.
osc=yes
osd-level=1
# Subtitles scaled for a 1080p portrait panel.
sub-font-size=44
EOF

if [ -f "$CFG/settings.json" ]; then
    echo "settings.json already exists, leaving it"
else
    cat > "$CFG/settings.json" <<'EOF'
{
    "fullscreen": true,
    "enable_gui": true,
    "gamepad": true,
    "gamepad_deadzone": 25,
    "auto_play": true,
    "media_keys": true,
    "remote_control": true
}
EOF
fi

chown -R duo:duo /home/duo/.var/app/$APP
echo "=== mpv.conf"
cat "$CFG/mpv.conf"
echo "=== settings.json"
cat "$CFG/settings.json"
echo
echo "=== does mpv under Wayland honour fs-screen-name?"
su - duo -c "HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 \
    flatpak run --command=mpv $APP --list-options 2>/dev/null | grep -E '^ (fs-screen|fs-screen-name|hwdec)'" 2>&1
