#!/bin/sh
# Install sherpa-onnx in an isolated venv (Debian 13 blocks system pip).
set -u
echo "=== installing venv + pip"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3-venv python3-pip >/tmp/stt-apt.log 2>&1
echo "  rc=$? $(tail -1 /tmp/stt-apt.log)"

VENV=/opt/duo-stt/venv
mkdir -p /opt/duo-stt
if [ ! -x "$VENV/bin/python" ]; then
    python3 -m venv "$VENV" 2>&1 | tail -3
fi
echo "  venv python: $("$VENV/bin/python" --version 2>&1)"

echo
echo "=== installing sherpa-onnx"
"$VENV/bin/pip" install --quiet --upgrade pip >/dev/null 2>&1
"$VENV/bin/pip" install sherpa-onnx 2>&1 | tail -4
echo
"$VENV/bin/python" - <<'PY'
try:
    import sherpa_onnx
    print("  sherpa-onnx version:", getattr(sherpa_onnx, "__version__", "unknown"))
except Exception as e:
    print("  import failed:", e)
PY
du -sh /opt/duo-stt 2>/dev/null | sed 's/^/  size: /'
