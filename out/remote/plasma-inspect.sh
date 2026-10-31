#!/bin/bash
# Inspect Plasma panels and desktop containments over D-Bus (no GUI needed).
set -u
export XDG_RUNTIME_DIR=/run/user/1000
export WAYLAND_DISPLAY=wayland-0

run_js() {
    su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 \
        dbus-send --session --print-reply --dest=org.kde.plasmashell /PlasmaShell \
        org.kde.PlasmaShell.evaluateScript string:'$1'" 2>&1
}

echo "=== panels and desktops"
run_js 'var out=[]; panels().forEach(function(p){ out.push("PANEL id="+p.id+" screen="+p.screen+" loc="+p.location+" h="+p.height+" vis="+p.visibility+" widgets="+p.widgets().map(function(w){return w.type}).join(",")) }); desktops().forEach(function(d){ out.push("DESKTOP id="+d.id+" screen="+d.screen+" widgets="+d.widgets().map(function(w){return w.type}).join(",")) }); out.join("|")' \
    | grep -o 'PANEL[^"]*\|DESKTOP[^"]*' | tr '|' '\n'
echo
echo "=== screens as plasma sees them"
run_js 'var o=[]; screenCount().toString()' | grep -o '"[0-9]*"' | head -3
