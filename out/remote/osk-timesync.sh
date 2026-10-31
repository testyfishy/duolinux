#!/bin/bash
set -u
export DEBIAN_FRONTEND=noninteractive
echo "=== on-screen keyboard candidates"
apt-cache search --names-only 'wvkbd|squeekboard|onboard|matchbox-keyboard' 2>&1 | head -10
echo "=== time sync candidates"
apt-cache policy chrony systemd-timesyncd 2>&1 | grep -E 'chrony|timesyncd|Candidate' | head -8
echo "=== install"
apt-get -o Acquire::ForceIPv4=true install -y --no-install-recommends chrony squeekboard 2>&1 | tail -6
echo "=== check"
for b in chronyc squeekboard; do printf '%-12s %s\n' "$b" "$(command -v "$b" 2>/dev/null || echo MISSING)"; done
systemctl enable --now chrony 2>&1 | tail -2
sleep 3
chronyc tracking 2>&1 | head -6
