#!/bin/sh
# Install Flatpak + Flathub + Moonlight (upstream streaming client).
set -u
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq flatpak >/tmp/flatpak-install.log 2>&1
echo "flatpak: $(flatpak --version 2>/dev/null)"

flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>&1 | tail -2
echo "remotes: $(flatpak remotes 2>/dev/null | tr '\n' ' ')"

# Moonlight needs the runtime too; this is a few hundred MB.
flatpak install -y --noninteractive flathub com.moonlight_stream.Moonlight >/tmp/moonlight-install.log 2>&1
echo "install rc=$?"
tail -3 /tmp/moonlight-install.log

echo
echo "=== installed apps"
flatpak list --app --columns=application,version,branch 2>/dev/null | head -5
echo
echo "=== size"
du -sh /var/lib/flatpak 2>/dev/null
