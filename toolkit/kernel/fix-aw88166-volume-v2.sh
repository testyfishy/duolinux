#!/bin/bash
# aw88166: expose the volume control as "attenuation below the profile default".
#
# Current behaviour: real = min(value + init_volume, 1023). The profile's
# init_volume is 512, so at control 0 the amp sits at -64 dB and nothing
# userspace can do will go louder. That is the quietness.
#
# New behaviour: the profile default stays the *starting point*, and the control
# lowers attenuation from there toward a -6 dB floor. 0 dB is deliberately never
# reachable: that is the hardware maximum and would overdrive these small
# speakers.
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
	 * The field is an ATTENUATION counter in 0.125 dB steps: 0 is the loudest
	 * the hardware can go, 1023 is silence. The profile's init_volume (512 on
	 * this board, i.e. -64 dB) is its default, and adding the control value to
	 * it meant userspace could only ever make things QUIETER - which is why
	 * 100% sounded the same as 0%.
	 *
	 * Treat the control as "how far to come down from the profile default",
	 * stopping at a -6 dB floor. 0 dB is deliberately unreachable: it is the
	 * amplifier's maximum and would overdrive these small speakers.
	 */
	{
		unsigned int atten = vol_desc->init_volume;
		const unsigned int floor = AW88166_MIN_ATTEN;

		if (value < atten - floor)
			atten -= value;
		else
			atten = floor;
		real_value = atten;
	}
"""
if old not in src:
    sys.exit("pattern not found")
src = src.replace(old, new, 1)

# define the floor next to the existing volume constant
hdr = p[:-2] + ".h"
h = io.open(hdr).read()
if "AW88166_MIN_ATTEN" not in h:
    h = h.replace(
        "#define AW88166_MUTE_VOL\t\t(1023)",
        "#define AW88166_MUTE_VOL\t\t(1023)\n/* -6 dB of headroom below the amp's maximum, in 0.125 dB steps */\n#define AW88166_MIN_ATTEN\t\t(48)", 1)
    io.open(hdr, "w", newline="\n").write(h)

io.open(p, "w", newline="\n").write(src)
print("patched")
PY

git diff -- sound/soc/codecs/aw88166.c sound/soc/codecs/aw88166.h > "$P/0001-aw88166-usable-volume-with-margin.patch"
echo "  patch saved: $(wc -l < "$P/0001-aw88166-usable-volume-with-margin.patch") lines"

echo
echo "=== new function"
sed -n '/static int aw_dev_set_volume/,/^}/p' "$F" | head -32 | sed 's/^/  /'
echo "=== header"
grep -n "MIN_ATTEN\|MUTE_VOL" "$K/sound/soc/codecs/aw88166.h" | sed 's/^/  /'
