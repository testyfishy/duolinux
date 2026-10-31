#!/bin/sh
# Decide whether the panel loop is a KSycoca invalidation storm.
#
# Starts plasmashell with ksycoca/KDirWatch logging on, adds a stock Kickoff,
# and reports repeated "databaseChanged"/rebuild messages, CPU, and the
# environment differences the advisor asked about.
su - duo -c 'pkill -x plasmashell; sleep 3'

su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 XDG_MENU_PREFIX=plasma- QML_XHR_ALLOW_FILE_READ=1 QT_LOGGING_RULES='kf.service.*=true;kf.coreaddons.kdirwatch=true' setsid plasmashell >/tmp/pl-dbg.log 2>&1 < /dev/null &"

sleep 20

cat > /tmp/k.js <<'EOF'
var p = panels()[0];
var k = p.addWidget("org.kde.plasma.kickoff");
print("kickoff added: " + (k !== null));
EOF

su - duo -c "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \"\$(cat /tmp/k.js)\""

sleep 40

echo "=== total log lines:"
wc -l < /tmp/pl-dbg.log
echo "=== sycoca-related line count:"
grep -ciE "sycoca|databaseChanged|kdirwatch" /tmp/pl-dbg.log
echo "=== repeated message shapes:"
grep -iE "sycoca|databaseChanged|kdirwatch" /tmp/pl-dbg.log | sed 's/[0-9][0-9]*/N/g' | sort | uniq -c | sort -rn | head -12
echo "=== sample:"
grep -iE "sycoca|databaseChanged|kdirwatch" /tmp/pl-dbg.log | head -8

echo "=== CPU (kickoff on panel):"
P=$(pgrep -x plasmashell | head -1)
top -H -b -d 20 -n 2 -p "$P" | awk '/PID USER/{c++} c==2' | head -3

echo "=== environment comparison:"
for name in plasmashell kded6 kwin_wayland; do
    pid=$(pgrep -x "$name" | head -1)
    echo "-- $name pid=$pid"
    [ -n "$pid" ] && tr '\0' '\n' < "/proc/$pid/environ" | grep -E '^(TZ|XDG_DATA_DIRS|XDG_CONFIG_DIRS|XDG_MENU_PREFIX|XDG_CURRENT_DESKTOP)='
done

echo "=== cache state:"
ls -ld /home/duo/.cache 2>&1
ls -l /home/duo/.cache/ksycoca6_* 2>&1 | head -3

echo "=== rebuild exits cleanly as duo:"
su - duo -c 'XDG_RUNTIME_DIR=/run/user/1000 kbuildsycoca6 --noincremental >/tmp/kbs.out 2>&1; echo exit=$?; tail -3 /tmp/kbs.out'

echo "=== how was the session started:"
tr '\0' ' ' < "/proc/$P/cmdline"; echo
ls /usr/share/wayland-sessions/ 2>&1
grep -c '^' /tmp/pl-dbg.log
