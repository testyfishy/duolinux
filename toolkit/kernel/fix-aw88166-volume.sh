#!/bin/bash
# Apply the aw88166 volume fix to our tree.
#
# The hardware field is an ATTENUATION counter (0 = loudest, 1023 = silence),
# but the control exposes 0..1023 straight through, so userspace "100%" wrote
# maximum attenuation. Invert it and stop adding the profile's init_volume,
# which offset the dB scale.
set -euo pipefail
K=$HOME/rocknix-nf/port/repo
F=$K/sound/soc/codecs/aw88166.c
P=$HOME/rocknix-nf/port/patches
mkdir -p "$P"

cd "$K"
git checkout -q -- sound/soc/codecs/aw88166.c 2>/dev/null || true

python3 - "$F" <<'PY'
import io, sys
p = sys.argv[1]
src = io.open(p).read()

old = """	real_value = min((value + vol_desc->init_volume), (unsigned int)AW88166_MUTE_VOL);
"""
new = """	/*
	 * The volume field is an attenuation counter: 0 is the loudest setting
	 * and AW88166_MUTE_VOL is silence. Userspace expects the opposite, so
	 * invert it. The profile's init_volume is deliberately not added: doing
	 * so offset the dB scale and made 100% quieter than 0%.
	 */
	if (value > AW88166_MUTE_VOL)
		value = AW88166_MUTE_VOL;
	real_value = AW88166_MUTE_VOL - value;
"""
if old not in src:
    sys.exit("pattern not found - driver already patched?")
src = src.replace(old, new, 1)
io.open(p, "w", newline="\n").write(src)
print("aw88166.c patched")
PY

# keep an inspectable patch in the repo
git diff -- sound/soc/codecs/aw88166.c > "$P/0001-aw88166-invert-volume-mapping.patch"
echo "  patch: $P/0001-aw88166-invert-volume-mapping.patch"
sed -n '1,25p' "$P/0001-aw88166-invert-volume-mapping.patch" | sed 's/^/    /'

echo
echo "=== resulting function"
sed -n '/static int aw_dev_set_volume/,/^}/p' "$F" | head -22 | sed 's/^/  /'
