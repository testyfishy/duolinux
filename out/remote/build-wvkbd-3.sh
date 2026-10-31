#!/bin/bash
set -u
cd /root/wvkbd-0.15 || exit 1

python3 - <<'PY'
import pathlib
p = pathlib.Path("/root/wvkbd-0.15/main.c")
t = p.read_text()
t = t.replace('(!strcmp(argv[i], "-O")) || (!strcmp(argv[i], "--output"))',
              '(!strcmp(argv[i], "--output"))')
t = t.replace('fprintf(stderr, "  -O, --output NAME - Bind the keyboard to this output\\n");',
              'fprintf(stderr, "  --output NAME - Bind the keyboard to this output\\n");')
p.write_text(t)
print("short -O removed; long form only")
PY

make clean >/dev/null 2>&1
make 2>&1 | tail -3
install -m 755 wvkbd-mobintl /usr/local/bin/wvkbd-mobintl
echo "=== options now:"
/usr/local/bin/wvkbd-mobintl --help 2>&1 | grep -iE "output|intersected"
