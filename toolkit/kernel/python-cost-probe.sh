#!/bin/sh
# What do our Python daemons actually cost?
set -u
echo "=== memory"
free -h | sed 's/^/  /'
echo "  zram: $(cat /sys/block/zram0/mm_stat 2>/dev/null | awk '{printf "%.0f MiB used", $3/1048576}')"

echo
echo "=== every python3 process"
printf '  %-8s %-7s %-7s %-8s %s\n' PID RSS_kB %CPU TIME_CPU COMMAND
for p in $(pgrep -f python3 2>/dev/null); do
    [ -r "/proc/$p/stat" ] || continue
    rss=$(awk '/VmRSS/{print $2}' "/proc/$p/status" 2>/dev/null)
    cpu=$(ps -o %cpu= -p "$p" 2>/dev/null | tr -d ' ')
    tim=$(ps -o time= -p "$p" 2>/dev/null | tr -d ' ')
    cmd=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | cut -c1-48)
    printf '  %-8s %-7s %-7s %-8s %s\n' "$p" "${rss:-?}" "${cpu:-?}" "${tim:-?}" "$cmd"
done

echo
echo "=== totals"
py_pids=$(pgrep -f python3 2>/dev/null | wc -l)
py_rss=$(for p in $(pgrep -f python3 2>/dev/null); do awk '/VmRSS/{print $2}' "/proc/$p/status" 2>/dev/null; done | awk '{s+=$1} END{printf "%.1f", s/1024}')
echo "  python processes: $py_pids, total RSS: ${py_rss} MiB"

echo
echo "=== top RSS overall"
ps -eo rss,comm --sort=-rss 2>/dev/null | head -12 | awk '{printf "  %6.1f MiB  %s\n", $1/1024, $2}'

echo
echo "=== wakeups of our daemons since boot (voluntary + involuntary)"
for p in $(pgrep -f "duo-|python3" 2>/dev/null); do
    n=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | cut -c1-28)
    [ -n "$n" ] || continue
    v=$(awk '/voluntary_ctxt_switches/{print $2}' "/proc/$p/status" 2>/dev/null)
    nv=$(awk '/nonvoluntary_ctxt_switches/{print $2}' "/proc/$p/status" 2>/dev/null)
    up=$(awk '{print $1}' /proc/uptime)
    [ -n "$v" ] && echo "  $n vol=$v nonvol=$nv  (~$(( (v+nv) / ${up%.*} )) /s)"
done | sort -t= -k2 -rn | head -10
