#!/bin/sh
# Unique memory (PSS) — shared pages counted once, proportionally.
set -u
pss() {
    awk '/^Pss:/{print $2}' "/proc/$1/smaps_rollup" 2>/dev/null
}
printf '  %-34s %8s %8s\n' PROCESS PSS_MiB RSS_MiB
tot=0
for p in $(pgrep -f python3 2>/dev/null); do
    n=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | awk '{print $2}' | xargs -r basename 2>/dev/null)
    v=$(pss "$p"); r=$(awk '/VmRSS/{print $2}' "/proc/$p/status" 2>/dev/null)
    [ -n "$v" ] || continue
    printf '  %-34s %8.1f %8.1f\n' "${n:-pid$p}" "$((v))e-3" "$((r))e-3" 2>/dev/null || \
    printf '  %-34s %8.1f %8.1f\n' "${n}" "$(echo "$v 1024" | awk '{print $1/$2}')" "$(echo "$r 1024" | awk '{print $1/$2}')"
    tot=$((tot + v))
done
echo "  python total PSS: $(echo "$tot 1024" | awk '{printf "%.1f", $1/$2}') MiB"

echo
echo "=== biggest unique-memory processes on the system"
for p in $(ps -eo pid --sort=-rss --no-headers | head -18); do
    v=$(pss "$p"); [ -n "$v" ] || continue
    n=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | cut -c1-40)
    echo "$v|$n"
done | sort -t'|' -k1 -rn | head -12 | awk -F'|' '{printf "  %7.1f MiB  %s\n", $1/1024, $2}'

echo
echo "=== cpu time of our daemons (against uptime)"
up=$(cut -d. -f1 /proc/uptime)
for p in $(pgrep -f "duo-" 2>/dev/null); do
    n=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | awk '{print $2}' | xargs -r basename)
    t=$(awk '{print $14+$15}' "/proc/$p/stat" 2>/dev/null)   # utime+stime in ticks
    [ -n "$t" ] && echo "  $n: ${t} ticks over ${up}s = $(awk -v t="$t" -v u="$up" 'BEGIN{printf "%.2f%%", (t/100)/u*100}')"
done
