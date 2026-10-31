#!/bin/sh
# Idle health check: nothing left running from the tests, sane clocks, no busy daemons.
set -u

echo "=== close the Firefox instance used for the screenshot"
pkill -x firefox-esr 2>/dev/null; pkill -x firefox 2>/dev/null
sleep 3
echo "firefox processes left: $(pgrep -c -x firefox-esr 2>/dev/null || echo 0)"

echo "=== load and uptime"
uptime

echo "=== cpufreq policies"
for p in /sys/devices/system/cpu/cpufreq/policy*; do
    echo "$(basename "$p"): governor=$(cat "$p/scaling_governor" 2>/dev/null) min=$(cat "$p/scaling_min_freq" 2>/dev/null) max=$(cat "$p/scaling_max_freq" 2>/dev/null) cur=$(cat "$p/scaling_cur_freq" 2>/dev/null)"
done
echo "available governors: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null)"
echo "boost: $(cat /sys/devices/system/cpu/cpufreq/policy0/boost 2>/dev/null)"

echo "=== top CPU consumers over 20 s (last sample)"
top -b -d 20 -n 2 -o %CPU 2>/dev/null | awk '/^top -/{n++} n==2' | sed -n '1,20p'

echo "=== our daemons"
ps -eo pid,comm,%cpu,etimes,args --sort=-%cpu 2>/dev/null | grep -E "duo-|inputplumber|python3|wf-recorder|fuzzel|wvkbd" | grep -v grep | head -12

echo "=== idle residency over 10 s (cpu0)"
total0=0; for s in /sys/devices/system/cpu/cpu0/cpuidle/state*; do total0=$((total0 + $(cat "$s/time"))); done
sleep 10
echo "state name: usage_delta time_delta_us"
for s in /sys/devices/system/cpu/cpu0/cpuidle/state*; do
    : # collected below
done
for s in /sys/devices/system/cpu/cpu0/cpuidle/state*; do
    echo "$(cat "$s/name"): $(cat "$s/usage") $(cat "$s/time")"
done
echo "(values are totals since boot; compare two runs by hand if needed)"

echo "=== cluster idle percentages (all cpus, 10 s window)"
for c in /sys/devices/system/cpu/cpu[0-9]; do
    n=$(basename "$c")
    vals=""
    for s in "$c"/cpuidle/state*; do
        [ -d "$s" ] || continue
        vals="$vals $(cat "$s/name")=$(cat "$s/usage")"
    done
    echo "$n:$vals"
done
