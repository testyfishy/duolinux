#!/bin/sh
set -u
echo "=== installed"
for p in plasma-desktop plasma-workspace kwin-wayland plasma-workspace-wayland libplasma6 qt6-base; do
    v=$(dpkg -l "$p" 2>/dev/null | awk '/^ii/{print $3}')
    [ -n "$v" ] && echo "  $p: $v"
done
echo "  plasmashell: $(su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 plasmashell --version' 2>/dev/null || echo '?')"
echo "  kwin:        $(su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 kwin_wayland --version' 2>/dev/null || echo '?')"
echo "  Qt:          $(dpkg -l 'libqt6core6*' 2>/dev/null | awk '/^ii/{print $3}' | head -1)"

echo
echo "=== sources"
grep -hE "^deb " /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null | sed 's/^/  /'
grep -hE "^(Suites|Components):" /etc/apt/sources.list.d/*.sources 2>/dev/null | sed 's/^/  /'

echo
echo "=== candidates"
for p in plasma-desktop plasma-workspace kwin-wayland; do
    echo "  $p: installed=$(apt-cache policy $p 2>/dev/null | awk '/Installed/{print $2}') candidate=$(apt-cache policy $p 2>/dev/null | awk '/Candidate/{print $2}')"
done

echo
echo "=== pinned?"
ls /etc/apt/preferences.d/ 2>/dev/null
echo "  hold: $(apt-mark showhold 2>/dev/null | tr '\n' ' ')"

echo
echo "=== the bug report device-side"
echo "  kameleon installed: $(dpkg -l | grep -c kameleon)"
echo "  KDE bug ref in docs: $(grep -rl 528087 /mnt/c/Users/*/Documents/Default\ Project/duolinux 2>/dev/null | wc -l)"
