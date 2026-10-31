#!/bin/sh
# Fix the per-user flatpak dirs (installed as root) and check the CLI.
set -u
ls -ld /home/duo/.var 2>/dev/null || echo "  .var missing"
mkdir -p /home/duo/.var/app
chown -R duo:duo /home/duo/.var
echo "  after: $(ls -ld /home/duo/.var | awk '{print $1, $3":"$4}')"

echo
echo "=== moonlight cli help"
su - duo -c 'HOME=/home/duo XDG_RUNTIME_DIR=/run/user/1000 \
    flatpak run com.moonlight_stream.Moonlight --help' 2>&1 | head -25
