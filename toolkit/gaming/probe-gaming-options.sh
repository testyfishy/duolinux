#!/bin/sh
set -u
echo "=== 32-bit story (the crux for Steam and 32-bit games)"
echo "  foreign arches: $(dpkg --print-foreign-architectures | tr '\n' ' ')"
echo "  armhf libs: $(dpkg -l | awk '/^ii/ && $2 ~ /:armhf/{c++} END{print c+0}')"
echo "  i386 libs:  $(dpkg -l | awk '/^ii/ && $2 ~ /:i386/{c++} END{print c+0}')"
apt-cache policy box86 2>/dev/null | head -3
echo "  armhf port enabled in apt: $(grep -c 'armhf' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null | paste -sd+ | bc 2>/dev/null || echo 0)"

echo
echo "=== streaming alternatives (much lighter than translating x86)"
for p in moonlight-qt moonlight-embedded steamlink flatpak sunshine; do
    pol=$(apt-cache policy "$p" 2>/dev/null | sed -n 's/.*Candidate: //p' | head -1)
    echo "  $p: ${pol:-not packaged}"
done
echo "  flatpak installed: $(command -v flatpak >/dev/null && flatpak --version || echo no)"

echo
echo "=== syncthing state"
systemctl is-enabled syncthing@duo.service 2>/dev/null || echo "  not enabled as user service"
systemctl --user is-active syncthing 2>/dev/null || true
echo "  package: $(dpkg -l syncthing 2>/dev/null | awk '/^ii/{print $3}')"
echo "  config dir: $(ls -d /home/duo/.local/state/syncthing 2>/dev/null || echo none)"

echo
echo "=== tailscale state"
tailscale status 2>&1 | head -2
echo "  service: $(systemctl is-active tailscaled)"

echo
echo "=== what games could plausibly run natively"
echo "  gpu: Adreno 610 (Turnip ICD present)"
echo "  ram available: $(free -m | awk '/Mem:/{print $7}') MiB"
echo "  cpu: $(nproc) cores"
