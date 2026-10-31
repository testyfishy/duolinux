#!/bin/bash
# Is the empty output a 2.0.1 regression? Test the 1.x line in a separate venv.
set -u
VENV=/opt/duo-stt/venv1
if [ ! -x "$VENV/bin/python" ]; then
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install -q --upgrade pip
    "$VENV/bin/pip" install -q "sherpa-onnx<2" 2>&1 | tail -2
fi
"$VENV/bin/python" -c 'import sherpa_onnx; print("version:", sherpa_onnx.__version__)'

M=/opt/duo-stt/models/sherpa-onnx-zipformer-en-2023-06-26
"$VENV/bin/python" - "$M" <<'PY'
import array, sys, time, wave
import sherpa_onnx

M = sys.argv[1]
rec = sherpa_onnx.OfflineRecognizer.from_transducer(
    encoder=f"{M}/encoder-epoch-99-avg-1.onnx",
    decoder=f"{M}/decoder-epoch-99-avg-1.onnx",
    joiner=f"{M}/joiner-epoch-99-avg-1.onnx",
    tokens=f"{M}/tokens.txt",
    num_threads=4,
    sample_rate=16000,
    feature_dim=80,
    decoding_method="greedy_search",
)
for name in ("0.wav", "8k.wav"):
    p = f"{M}/test_wavs/{name}"
    with wave.open(p) as f:
        sr = f.getframerate()
        a = array.array("h"); a.frombytes(f.readframes(f.getnframes()))
    samples = list(a)
    dur = len(samples) / sr
    t0 = time.perf_counter()
    s = rec.create_stream()
    s.accept_waveform(sr, samples)
    rec.decode_stream(s)
    dt = time.perf_counter() - t0
    print(f"  {name}: {dur:.2f}s -> {dt*1000:.0f} ms (RTF {dt/dur:.2f}) -> {s.result.text!r}")
PY
