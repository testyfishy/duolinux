#!/bin/sh
# Where do the CPU cycles actually go? Sample deltas over 30 s.
set -u
read_cpu() { awk '/^cpu /{print $2, $3, $4, $5, $6, $7, $8}' /proc/stat; }
snap_procs() {
    for p in /proc/[0-9]*; do
        pid=${p#/proc/}
        s=$(awk '{print $14, $15}' "$p/stat" 2>/dev/null) || continue
        c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null | cut -c1-45)
        [ -n "$c" ] && echo "$pid|$s|$c"
    done
}
read_cpu > /tmp/cpu1
snap_procs > /tmp/proc1
sleep 30
read_cpu > /tmp/cpu2
snap_procs > /tmp/proc2

echo "=== system-wide over 30 s"
paste -d' ' /tmp/cpu1 /tmp/cpu2 | awk '{
    u=$2-$8; n=$3-$9; s=$4-$10; i=$5-$11; io=$6-$12; ir=$7-$13; so=$7-$13;
    tot=u+n+s+i+io+0.0001;
    printf "  user %.1f%%  nice %.1f%%  system %.1f%%  idle %.1f%%  iowait %.1f%%  irq %.1f%%\n",
        u*100/tot, n*100/tot, s*100/tot, i*100/tot, io*100/tot, ir*100/tot;
    printf "  busy %.1f%% of one core-equivalent total\n", (tot-i-io)*100/tot;
}'

echo
echo "=== per-process CPU over the same 30 s (top 12)"
join -t'|' -j1 <(sort -t'|' -k1,1 /tmp/proc1) <(sort -t'|' -k1,1 /tmp/proc2) 2>/dev/null | \
awk -F'|' '{
    split($2,a," "); split($4,b," ");
    d=(b[1]+b[2])-(a[1]+a[2]);
    if (d>0) printf "%d|%s\n", d, $5
}' 2>/dev/null | sort -t'|' -k1 -rn | head -12 | \
awk -F'|' '{printf "  %5.2f%%  %s\n", $1/30, $2}' 2>/dev/null

echo
echo "=== tick note: 100 ticks/s per core, so 30 s = 3000 ticks per core"
