#!/bin/bash
set -u
cd /root/wvkbd-0.15 || exit 1

python3 - <<'PY'
import pathlib
p = pathlib.Path("/root/wvkbd-0.15/main.c")
t = p.read_text()

if "display_handle_description" not in t:
    t = t.replace(
        "static void\ndisplay_handle_name(void *data, struct wl_output *wl_output, const char *name)",
        """static void
display_handle_description(void *data, struct wl_output *wl_output,
                           const char *description)
{
    (void)data;
    (void)wl_output;
    (void)description;
}

static void
display_handle_name(void *data, struct wl_output *wl_output, const char *name)""",
        1,
    )
    t = t.replace("    .name = display_handle_name,",
                  "    .name = display_handle_name,\n    .description = display_handle_description,", 1)
    p.write_text(t)
    print("description handler added")
else:
    print("already present")
PY

make 2>&1 | tail -2
install -m 755 wvkbd-mobintl /usr/local/bin/wvkbd-mobintl
echo "=== smoke test (2s, then killed)"
S=$(ls /run/user/1000/sway-ipc.*.sock | head -1)
su - duo -c "SWAYSOCK=$S XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 timeout 2 /usr/local/bin/wvkbd-mobintl --output DP-1 -H 200 --hidden" 2>&1 | head -5
echo "rc=$?"
