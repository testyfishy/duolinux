#!/bin/bash
# Does the replayed 7.2.0 branch reproduce the tree that built the running kernel?
# Compares source files only (sha256), ignoring build artefacts and generated files.
set -uo pipefail
cd "$HOME/rocknix-nf/port/repo"
T=/tmp/series-72
rm -rf "$T"; mkdir -p "$T"
git archive rk-7.2-full | tar -x -C "$T"

list() {
    find "$1" -type f \
        \( -name '*.c' -o -name '*.h' -o -name '*.S' -o -name '*.dts' -o -name '*.dtsi' \
           -o -name 'Kconfig*' -o -name 'Makefile' -o -name '*.yaml' \) \
        ! -path '*/tools/*' ! -path '*/.git/*' -printf '%P\n' | sort
}
list "$T" > /tmp/a.lst
list "$HOME/rocknix-nf/src/linux-7.2" > /tmp/b.lst
echo "replayed files: $(wc -l < /tmp/a.lst), built-tree files: $(wc -l < /tmp/b.lst)"
echo "only in replayed: $(comm -23 /tmp/a.lst /tmp/b.lst | wc -l)"
echo "only in built:    $(comm -13 /tmp/a.lst /tmp/b.lst | wc -l)"
comm -13 /tmp/a.lst /tmp/b.lst | head -8 | sed 's/^/  built-only: /'

echo
echo "=== content differences among shared files"
n=0
while IFS= read -r f; do
    a="$T/$f"; b="$HOME/rocknix-nf/src/linux-7.2/$f"
    if ! cmp -s "$a" "$b"; then
        n=$((n+1)); echo "  DIFF $f"
    fi
done < <(comm -12 /tmp/a.lst /tmp/b.lst)
echo "differing shared files: $n"
