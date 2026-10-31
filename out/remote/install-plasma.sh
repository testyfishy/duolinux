#!/bin/bash
# Install KDE Plasma 6 alongside Sway (no display manager yet, so nothing
# changes at boot until we choose to switch).
set -u
export DEBIAN_FRONTEND=noninteractive

LOG=/var/log/plasma-install.log
: > "$LOG"

{
  echo "=== $(date) starting"
  apt-get -o Acquire::ForceIPv4=true update 2>&1 | tail -2
  apt-get -o Acquire::ForceIPv4=true install -y --no-install-recommends \
      kde-plasma-desktop plasma-workspace plasma-nm systemsettings \
      kscreen dolphin konsole plasma-discover breeze-icon-theme \
      plasma-widgets-addons 2>&1 | tail -25
  echo "=== $(date) done rc=$?"
  for b in startplasma-wayland plasmashell systemsettings dolphin konsole; do
      printf '%-24s %s\n' "$b" "$(command -v "$b" 2>/dev/null || echo MISSING)"
  done
} >> "$LOG" 2>&1
