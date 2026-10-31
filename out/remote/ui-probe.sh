#!/bin/bash
echo "=== gui/tui tooling"
for b in foot wofi fuzzel rofi dialog whiptail zenity yad nmtui nmcli gtk3-demo; do
  printf '%-12s %s\n' "$b" "$(command -v "$b" 2>/dev/null || echo -)"
done
echo "=== python gui libs"
for m in gi tkinter; do
  python3 -c "import $m; print('$m ok')" 2>/dev/null || echo "$m missing"
done
python3 -c 'import gi; gi.require_version("Gtk","3.0"); from gi.repository import Gtk; print("gtk3 ok")' 2>/dev/null || echo "gtk3 binding missing"
echo "=== fonts / scaling"
command -v swaymsg && swaymsg -t get_outputs 2>/dev/null | head -5
echo "=== current sway config head"
head -20 /etc/sway/config
echo "=== sway sockets"
ls -l /run/user/1000/wayland-* 2>/dev/null
