#!/bin/bash
set -u
D=/root/wvkbd-0.15
echo "=== Output struct (lines 50-70)"; sed -n '50,70p' "$D/main.c"
echo; echo "=== registry bind (455-480)"; sed -n '455,480p' "$D/main.c"
echo; echo "=== output listener decl (440-452)"; sed -n '440,452p' "$D/main.c"
echo; echo "=== get_layer_surface / create"; grep -n "get_layer_surface\|zwlr_layer_shell_v1" "$D/main.c"
echo; echo "=== argv parse (search)"; grep -n "argv\|argc" "$D/main.c" | head -20
echo; echo "=== usage text"; grep -n "usage\|fprintf(stderr" "$D/main.c" | head -10
