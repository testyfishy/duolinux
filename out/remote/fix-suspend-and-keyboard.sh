#!/bin/bash
# Stop the handheld suspending, and make the on-screen keyboard a single
# instance that actually toggles.
set -u

echo "=== 1. block suspend at the systemd level (powerdevil was still doing it)"
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>&1 | tail -4

echo "=== 2. single-instance keyboard"
cat > /usr/local/bin/duo-osk <<'EOF'
#!/bin/bash
# On-screen keyboard, bound to the BOTTOM panel by output name.
#
# Single instance is enforced with flock plus a PID file: the previous version
# checked pgrep then launched, so two concurrent invocations (a button press
# racing an init) both started, giving stacked keyboards and a toggle that
# appeared to reopen instead of close.
BOTTOM=DP-1
RUNTIME=/run/user/$(id -u)
PIDFILE="$RUNTIME/duo-osk.pid"
STATEFILE="$RUNTIME/duo-osk.on"
LOCK="$RUNTIME/duo-osk.lock"

exec 9>"$LOCK"
flock -w 5 9 || exit 1

CONF="$HOME/.config/duo/kbd-height"
H=560
[ -f "$CONF" ] && H=$(cat "$CONF")
case "$H" in ''|*[!0-9]*) H=560 ;; esac

running_pid() {
    [ -f "$PIDFILE" ] || return 1
    local pid
    pid=$(cat "$PIDFILE" 2>/dev/null)
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && echo "$pid"
}

kill_all() {
    pkill -x wvkbd-mobintl 2>/dev/null
    rm -f "$PIDFILE"
    sleep 0.3
}

wait_for_bottom() {
    # The bridge has no hotplug event; make sure DP-1 exists before creating a
    # layer surface, otherwise wvkbd falls back to the focused (top) output.
    for _ in $(seq 1 20); do
        [ "$(cat /sys/class/class 2>/dev/null)" ] && true
        if [ "$(cat /sys/class/drm/card0-DP-1/status 2>/dev/null)" = "connected" ]; then
            return 0
        fi
        sudo -n /usr/local/bin/duo-bottom-detect >/dev/null 2>&1 || true
        sleep 0.25
    done
    return 1
}

start_hidden() {
    wait_for_bottom || { echo "duo-osk: DP-1 not available" >&2; return 1; }
    wvkbd-mobintl \
        --output "$BOTTOM" \
        -H "$H" -L "$H" -R 10 \
        --fn "DejaVu Sans 22" \
        --alpha 255 \
        --bg 141417 --fg 2c2c2e --fg-sp 3a3a3c \
        --press 0a84ff --press-sp 0a84ff \
        --text ffffff --text-sp 9a9aa0 \
        --landscape-layers full,landscape,special,landscapespecial \
        --hidden >/dev/null 2>&1 &
    echo $! > "$PIDFILE"
    sleep 0.8
}

show() {
    local pid
    pid=$(running_pid) || { kill_all; start_hidden || return 1; pid=$(running_pid); }
    [ -n "$pid" ] && kill -USR2 "$pid" 2>/dev/null
    touch "$STATEFILE"
}

hide() {
    local pid
    pid=$(running_pid)
    [ -n "$pid" ] && kill -USR1 "$pid" 2>/dev/null
    rm -f "$STATEFILE"
}

case "${1:-toggle}" in
    --init)
        kill_all
        start_hidden && hide
        ;;
    restart)
        kill_all
        start_hidden && show
        ;;
    show)    show ;;
    hide)    hide ;;
    toggle)
        if [ -f "$STATEFILE" ]; then hide; else show; fi
        ;;
esac
EOF
chmod 755 /usr/local/bin/duo-osk
bash -n /usr/local/bin/duo-osk && echo "duo-osk syntax ok"

echo "=== 3. clean restart of the keyboard"
su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 /usr/local/bin/duo-osk restart" 2>&1 | tail -2
sleep 1
echo "instances now: $(pgrep -c -x wvkbd-mobintl)"
pgrep -af wvkbd-mobintl | head -2
