#!/bin/bash
# Does the TX macro program its DMIC clock register when the DEC mux actually
# changes? Mainline only writes CDC_TX_TOP_CSR_SWR_DMICn_CTL from the mux put
# handler, so a mux that was already set at card init leaves the register at its
# reset value.
set -u
PY=/opt/duo-stt/venv/bin/python
REG=/sys/kernel/debug/regmap/a460000.codec-tx_macro/registers

clk() { timeout 3 grep -E "^0c[048c]:" "$REG" | tr '\n' ' '; }

echo "=== before"
echo "  $(clk)"

alsactl store -f /tmp/muxbase.conf

setmux() {
    "$PY" - "$1" <<'PY'
import sys
val = sys.argv[1]
out, cur = [], None
for line in open("/tmp/muxbase.conf"):
    s = line.strip()
    if s.startswith("name '"):
        cur = s
    if s.startswith("value ") and cur == "name 'TX DEC0 MUX'":
        line = "\t\tvalue %s\n" % val
    out.append(line)
open("/tmp/mux.conf", "w").writelines(out)
PY
    alsactl restore -f /tmp/mux.conf 2>/dev/null
}

echo "=== switch DEC0 -> SWR_MIC"
setmux SWR_MIC
sleep 0.5
echo "  $(clk)"

echo "=== switch DEC0 -> MSM_DMIC"
setmux MSM_DMIC
sleep 0.5
echo "  $(clk)"

echo
echo "=== value of the mux after the round trip"
alsactl store -f /tmp/muxafter.conf
grep -A1 "name 'TX DEC0 MUX'" /tmp/muxafter.conf | tail -1 | sed 's/^/  /'

echo
echo "=== clock field decode (bits 3:1)"
timeout 3 grep -E "^0c4:" "$REG" | awk '{v=strtonum("0x" $2); printf "  0xC4 = 0x%04x -> field %d\n", v, (v >> 1) & 7}'
