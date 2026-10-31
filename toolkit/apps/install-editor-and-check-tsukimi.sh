#!/bin/sh
# Text editor(s) + what Tsukimi's player is complaining about.
set -u
echo "=== editors already present"
for e in kate gedit mousepad geany code nano vim micro; do
    echo "  $e: $(command -v $e || echo no)"
done

echo
echo "=== installing kate (KDE-native, touch friendly) + nano"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq kate nano >/tmp/editor-apt.log 2>&1
echo "  rc=$?  kate: $(command -v kate || echo missing)  nano: $(command -v nano || echo missing)"
tail -2 /tmp/editor-apt.log | sed 's/^/  /'

echo
echo "=== tsukimi player: recent errors"
grep -iE "error|warn|fail|gst|pipeline|codec|audio|vulkan|egl" /tmp/tsukimi.log 2>/dev/null | tail -15 | sed 's/^/  /'

echo
echo "=== is anything playing?"
ps -eo pid,pcpu,comm 2>/dev/null | grep -iE "tsukimi|mpv|gst" | grep -v grep | sed 's/^/  /'

echo
echo "=== audio sinks"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 wpctl status' 2>/dev/null | sed -n '/Sinks:/,/Sources:/p' | head -6 | sed 's/^/  /'
