#!/bin/sh
set -u
echo "=== does Tailscale ship its own tray (would replace 32 MiB of GTK)?"
tailscale systray --help 2>&1 | head -6
echo "  binary present: $(command -v tailscale-systray || echo no)"

echo
echo "=== journal rate of the other daemons (lines in the last 10 min)"
for u in duo-backkey duo-lid duo-brightness-guard duo-fan; do
    n=$(journalctl -u "$u" --since '-10 min' --no-pager 2>/dev/null | wc -l)
    echo "  $u: $n lines"
done

echo
echo "=== cpu of each daemon over its lifetime"
up=$(cut -d. -f1 /proc/uptime)
for p in $(pgrep -f 'duo-' 2>/dev/null); do
    n=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | awk '{print $2}' | xargs -r basename)
    t=$(awk '{print $14+$15}' "/proc/$p/stat" 2>/dev/null)
    [ -n "$t" ] && echo "  $n: $(awk -v t="$t" -v u="$up" 'BEGIN{printf "%.2f%%", (t/100)/u*100}') lifetime"
done

echo
echo "=== KDE services that could go"
for u in plasma-discover-notifier.service baloo_file kaccess akonadi_control; do
    echo "  $u: $(systemctl --user -M duo@.host is-active "$u" 2>/dev/null || systemctl is-active "$u" 2>/dev/null || echo n/a)"
done
echo "  autostart entries:"
ls /home/duo/.config/autostart/ 2>/dev/null | sed 's/^/    /'
echo "  running heavy helpers:"
ps -eo comm,rss --sort=-rss 2>/dev/null | grep -E "Discover|kaccess|baloo|akonadi" | head -5

echo
echo "=== is the Discover notifier actually needed?"
echo "  package: $(dpkg -l plasma-discover-notifier 2>/dev/null | awk '/^ii/{print $3}')"
