#!/usr/bin/env python3
"""Add --output NAME to wvkbd so the surface is bound to a named output."""
import pathlib
import sys

p = pathlib.Path("/root/wvkbd-0.15/main.c")
src = p.read_text()
orig = src

# 1. store the output name in the Output struct
src = src.replace(
    """struct Output {
    uint32_t name;""",
    """struct Output {
    uint32_t name;
    char *wlname;""",
    1,
)

# 2. globals for the requested output
src = src.replace(
    "static struct Output *current_output;",
    """static struct Output *current_output;
static const char *requested_output_name;
static struct wl_output *requested_output_data;""",
    1,
)

# 3. name handler + listener entry
src = src.replace(
    "static const struct wl_output_listener output_listener = {\n    .geometry",
    """static void
display_handle_name(void *data, struct wl_output *wl_output, const char *name)
{
    struct Output *output = data;
    if (!name)
        return;
    output->wlname = estrdup(name);
    if (requested_output_name && strcmp(name, requested_output_name) == 0)
        requested_output_data = wl_output;
}

static const struct wl_output_listener output_listener = {
    .name = display_handle_name,
    .geometry""",
    1,
)

# 4. bind wl_output v4 so the name event exists
src = src.replace(
    "wl_registry_bind(registry, name, &wl_output_interface, 2);",
    "wl_registry_bind(registry, name, &wl_output_interface, version < 4 ? version : 4);",
    1,
)

# 5. --output / -O option
src = src.replace(
    """        } else if (!strcmp(argv[i], "-l")) {""",
    """        } else if ((!strcmp(argv[i], "-O")) || (!strcmp(argv[i], "--output"))) {
            if (i >= argc - 1) {
                usage(argv[0]);
            }
            requested_output_name = estrdup(argv[++i]);
        } else if (!strcmp(argv[i], "-l")) {""",
    1,
)

# 6. use the requested output when creating the surface
src = src.replace(
    """    struct wl_output *current_output_data = NULL;
    if (current_output)
        current_output_data = current_output->data;""",
    """    struct wl_output *current_output_data = NULL;
    if (requested_output_name) {
        for (int tries = 0; tries < 20 && !requested_output_data; tries += 1)
            wl_display_roundtrip(display);
        current_output_data = requested_output_data;
    } else if (current_output) {
        current_output_data = current_output->data;
    }""",
    1,
)

# 7. usage text
src = src.replace(
    '    fprintf(stderr, "  -D          - Enable debug\\n");',
    '    fprintf(stderr, "  -D          - Enable debug\\n");\n'
    '    fprintf(stderr, "  -O, --output NAME - Bind the keyboard to this output\\n");',
    1,
)

if src == orig:
    print("ERROR: no changes applied")
    sys.exit(1)

p.write_text(src)
print("patched main.c")

for marker in ("requested_output_name", "display_handle_name", "--output"):
    print(f"  contains {marker}: {marker in src}")
