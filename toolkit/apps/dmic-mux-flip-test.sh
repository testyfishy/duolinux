#!/bin/bash
# Flip the DMIC input mux (not the DEC mux) and watch the DMIC clock registers.
# tx_macro_update_smic_sel*() programs CDC_TX_TOP_CSR_SWR_DMICn_CTL from the
# DMIC-mux put handler, so this is the only control that runs that code.
set -u
PY=/opt/duo-stt/venv/bin/python
REG=/sys/kernel/debug/regmap/a460000.codec-tx_macro/registers

clk() { timeout 3 grep -E "^0c[048c]:" "$REG" | tr '\n' ' '; }
alsactl store -f /tmp/base2.conf

setmux() {
    "$PY" - "$1" <<'PY'
import sys
val = sys.argv[1]
out, cur = [], None
for line in open("/tmp/base2.conf"):
    s = line.strip()
    if s.startswith("name '"):
        cur = s
    if s.startswith("value ") and cur == "name 'TX DMIC MUX0'":
        line = "\t\tvalue %s\n" % val
    out.append(line)
open("/tmp/mux2.conf", "w").writelines(out)
PY
    alsactl restore -f /tmp/mux2.conf 2>/dev/null
}

echo "=== current"
grep -A1 "name 'TX DMIC MUX0'" /tmp/base2.conf | tail -1 | sed 's/^/  value:/'
echo "  clk: $(clk)"

for m in DMIC3 DMIC0 DMIC2; do
    echo "=== TX DMIC MUX0 -> $m"
    setmux "$m"
    sleep 0.5
    echo "  clk: $(clk)"
done

echo
echo "=== after the round trip"
alsactl store -f /tmp/base3.conf
grep -A1 "name 'TX DMIC MUX0'" /tmp/base3.conf | tail -1 | sed 's/^/  value:/'
