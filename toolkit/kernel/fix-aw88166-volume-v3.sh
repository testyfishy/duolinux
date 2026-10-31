#!/bin/bash
# aw88166: give the amplifier a volume control with the right polarity.
#
# What the hardware does
#   Register 05 field [9:0] is an ATTENUATION counter in 0.125 dB steps:
#   0 = loudest the amp can go, 1023 = silence. The ACF profile's value is the
#   board's own default; on this board it measures 12, i.e. -1.5 dB.
#
# What the vendor driver does
#   real = min(value + init_volume, 1023). So the ALSA control ADDS attenuation:
#   0 is the profile default (loud) and 1023 is mute. Every consumer of an ALSA
#   playback control assumes the opposite - PipeWire maps 100% to the control
#   maximum - so at "100%" PipeWire was writing 1023 and muting the amp. That
#   is the quietness: not a level problem, a polarity problem.
#
# What this patch does
#   Invert the control across the full hardware range, and make the loudest
#   reachable setting the profile's own default rather than 0 dB:
#
#     control 0      -> attenuation 1023 (silence)
#     control 1023   -> attenuation init_volume (the vendor's design point)
#
#   Mute, fade-in and fade-out keep the upstream attenuation semantics, because
#   the conversion happens only at the ALSA control boundary.
set -euo pipefail
K=$HOME/rocknix-nf/port/repo
F=$K/sound/soc/codecs/aw88166.c
P=$HOME/rocknix-nf/port/patches
mkdir -p "$P"

cd "$K"
git checkout -q -- sound/soc/codecs/aw88166.c sound/soc/codecs/aw88166.h 2>/dev/null || true

python3 - "$F" <<'PY'
import io, sys

p = sys.argv[1]
src = io.open(p).read()

def sub(old, new, count=1, why=""):
    global src
    n = src.count(old)
    if n != count:
        sys.exit("expected %d occurrence(s) of %r, found %d %s" % (count, old[:60], n, why))
    src = src.replace(old, new, count)

# 1. set_volume works in attenuation units again, exactly as the fades need
sub(
"""	real_value = min((value + vol_desc->init_volume), (unsigned int)AW88166_MUTE_VOL);
""",
"""	/*
	 * `value` is the ATTENUATION counter in 0.125 dB steps: 0 is the loudest
	 * the hardware can go and 1023 is silence. Callers (fade-in, fade-out,
	 * mute) work in that unit; the ALSA control converts at its boundary.
	 */
	if (value > AW88166_MUTE_VOL)
		value = AW88166_MUTE_VOL;
	real_value = (u16)value;
""")

# 2. the control <-> attenuation mapping
sub(
"""static int aw_dev_set_volume(struct aw_device *aw_dev, unsigned int value)
""",
"""/*
 * The ACF profile states the amplifier's own default attenuation; 512 (-64 dB)
 * is used only as a fallback when the profile omits the register entirely.
 */
#define AW88166_CTL_INIT_FALLBACK	(512)

static unsigned int aw88166_init_atten(struct aw_device *aw_dev)
{
	unsigned int init = aw_dev->volume_desc.init_volume;

	if (!init || init > AW88166_MUTE_VOL)
		init = AW88166_CTL_INIT_FALLBACK;

	return init;
}

/*
 * ALSA control 0 is silence, control 1023 is the loudest this board should
 * ever be: the profile's own default attenuation. 0 dB stays unreachable.
 */
static u16 aw_dev_ctl_to_atten(struct aw_device *aw_dev, unsigned int ctl)
{
	unsigned int init = aw88166_init_atten(aw_dev);

	if (ctl >= AW88166_MUTE_VOL)
		return (u16)init;

	return (u16)(AW88166_MUTE_VOL -
		     ((AW88166_MUTE_VOL - init) * ctl) / AW88166_MUTE_VOL);
}

static u16 aw_dev_atten_to_ctl(struct aw_device *aw_dev, unsigned int atten)
{
	unsigned int init = aw88166_init_atten(aw_dev);

	if (atten <= init)
		return AW88166_MUTE_VOL;
	if (atten >= AW88166_MUTE_VOL)
		return 0;

	return (u16)(((AW88166_MUTE_VOL - atten) * AW88166_MUTE_VOL) /
		     (AW88166_MUTE_VOL - init));
}

static int aw_dev_set_volume(struct aw_device *aw_dev, unsigned int value)
""")

# 3. fades stay in attenuation units
sub(
"""	u16 fade_in_vol = desc->ctl_volume;
""",
"""	u16 fade_in_vol = aw_dev_ctl_to_atten(aw_dev, desc->ctl_volume);
""")

sub(
"""	for (i = desc->ctl_volume; i <= AW88166_MUTE_VOL; i += fade_step) {
""",
"""	for (i = aw_dev_ctl_to_atten(aw_dev, desc->ctl_volume);
	     i <= AW88166_MUTE_VOL; i += fade_step) {
""")

# 4. start applies the converted value
sub(
"""		aw_dev_set_volume(aw_dev, vol_desc->ctl_volume);
""",
"""		aw_dev_set_volume(aw_dev, aw_dev_ctl_to_atten(aw_dev, vol_desc->ctl_volume));
""")

# 5. the control stores the user value and converts on the way to hardware
sub(
"""	if (vol_desc->ctl_volume != value) {
		vol_desc->ctl_volume = value;
		aw_dev_set_volume(aw88166->aw_pa, vol_desc->ctl_volume);
""",
"""	if (vol_desc->ctl_volume != value) {
		vol_desc->ctl_volume = value;
		aw_dev_set_volume(aw88166->aw_pa,
				  aw_dev_ctl_to_atten(aw88166->aw_pa, value));
""")

# 6. read back what is actually reachable, so the control cannot show a level
#    the hardware is not at
sub(
"""	ucontrol->value.integer.value[0] = vol_desc->ctl_volume;
""",
"""	ucontrol->value.integer.value[0] =
		aw_dev_atten_to_ctl(aw88166->aw_pa,
				    aw_dev_ctl_to_atten(aw88166->aw_pa,
							vol_desc->ctl_volume));
""")

# 7. the driver's own "unset" volume must mean "as loud as the profile allows",
#    not silence: 0 is now the bottom of the inverted control
sub(
"""		vol_desc->ctl_volume = 0;
""",
"""		vol_desc->ctl_volume = AW88166_MUTE_VOL;
""")

sub(
"""	aw_dev->volume_desc.ctl_volume = AW88166_VOL_DEFAULT_VALUE;
""",
"""	aw_dev->volume_desc.ctl_volume = AW88166_MUTE_VOL;
""")

io.open(p, "w", newline="\n").write(src)
print("patched aw88166.c")
PY

git diff -- sound/soc/codecs/aw88166.c sound/soc/codecs/aw88166.h \
    > "$P/0001-aw88166-usable-volume-with-margin.patch"
echo "  patch: $(wc -l < "$P/0001-aw88166-usable-volume-with-margin.patch") lines"

echo
echo "=== mapping"
sed -n '/aw_dev_ctl_to_atten/,/^}/p' "$F" | sed 's/^/  /'
echo "=== call sites"
grep -n "aw_dev_ctl_to_atten\|aw_dev_atten_to_ctl" "$F" | sed 's/^/  /'
echo
echo "=== sanity: 0 -> mute, 1023 -> profile default"
python3 - <<'PY'
def atten(ctl, init):
    if ctl >= 1023:
        return init
    return 1023 - ((1023 - init) * ctl) // 1023
for init in (12, 512):
    print("  init_volume=%d:" % init,
          ", ".join("ctl %4d -> atten %4d" % (c, atten(c, init))
                    for c in (0, 256, 512, 767, 1023)))
PY
