#!/bin/sh
# Post-boot verification of 7.2.11-nf.
set -u
U="su - duo -c"
run_as() { su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 $*" 2>/dev/null; }

echo "=== kernel"
echo "  $(uname -r) / uptime $(uptime -p)"

echo "=== display outputs"
run_as kscreen-doctor -o | grep -E "^Output|^\s+Enabled|^\s+Geometry|^\s+Scale" | head -24

echo "=== drm connectors"
for s in /sys/class/drm/card*-*/status; do
    echo "  $(cat "$s")  $(dirname "$s" | xargs basename)"
done

echo "=== backlight"
for b in /sys/class/backlight/*; do
    echo "  $(basename "$b"): $(cat "$b/brightness")/$(cat "$b/max_brightness")"
done

echo "=== display errors in dmesg"
dmesg | grep -iE "dsi|panel|bridge|dpu|wl818s|drm" | grep -iE "error|fail|timeout|defer" | head -8
echo "  (count: $(dmesg | grep -iE "dsi|panel|bridge|dpu|wl818s|drm" | grep -icE "error|fail|timeout"))"

echo "=== network"
echo "  wifi: $(nmcli -t -f STATE g 2>/dev/null) / $(iwgetid -r 2>/dev/null)"

echo "=== netfilter"
echo "  nft: $(nft list ruleset >/dev/null 2>&1 && echo ok || echo FAIL)"
echo "  rules: $(nft list ruleset 2>/dev/null | wc -l)"

echo "=== tailscale"
echo "  service: $(systemctl is-active tailscaled 2>/dev/null)"
echo "  ip: $(tailscale ip -4 2>/dev/null | head -1)"
echo "  state: $(tailscale status --json 2>/dev/null | grep -o '\"BackendState\":\"[^\"]*\"' | head -1)"

echo "=== remoteproc"
for r in /sys/class/remoteproc/*; do echo "  $(basename "$r"): $(cat "$r/state" 2>/dev/null)"; done

echo "=== power"
echo "  supplies: $(ls /sys/class/power_supply | tr '\n' ' ')"
for p in /sys/class/power_supply/*; do
    n=$(basename "$p")
    [ -r "$p/capacity" ] && echo "  $n: $(cat "$p/capacity")% $(cat "$p/status" 2>/dev/null)"
done

echo "=== audio"
run_as wpctl status | grep -E "Sinks:|default" | head -4

echo "=== desktop"
echo "  plasmashell: $(su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active plasma-plasmashell' 2>/dev/null)"
echo "  failed units: $(systemctl list-units --state=failed --no-legend | wc -l)"
