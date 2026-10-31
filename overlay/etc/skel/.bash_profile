if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec /usr/local/bin/duo-session
fi
if [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
