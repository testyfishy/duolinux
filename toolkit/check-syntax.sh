#!/bin/bash
cd "/mnt/c/Users/user/Documents/Default Project/duolinux" || exit 1
fails=0
while IFS= read -r f; do
    if ! bash -n "$f" 2>/tmp/syn.err; then
        echo "SYNTAX $f: $(head -1 /tmp/syn.err)"
        fails=$((fails+1))
    fi
done < <(find toolkit -name '*.sh')
echo "shell scripts checked: $(find toolkit -name '*.sh' | wc -l), failures: $fails"

echo "=== remaining LAN addresses anywhere"
git grep -nE '192\.168\.[0-9]+\.[0-9]+' -- . | head -5 || echo "  none"
echo "=== python syntax"
python3 -m py_compile toolkit/kernel/cpu-profile.py toolkit/kernel/test-fan-replay.py && echo "  ok"
