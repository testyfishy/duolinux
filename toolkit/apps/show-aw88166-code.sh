#!/bin/bash
set -uo pipefail
K=$HOME/rocknix-nf/port/repo/sound/soc/codecs
echo "=== aw_dev_set_volume"
sed -n '/static int aw_dev_set_volume/,/^}/p' "$K/aw88166.c"
echo
echo "=== volume control definition"
grep -n -B3 -A6 "PCM Playback Volume" "$K/aw88166.c"
echo
echo "=== header volume constants"
grep -n "MUTE_VOL\|VOL_MAX\|VOL_MIN" "$K/aw88166.h" | head -8
echo
echo "=== aw88166_volume_set / get"
sed -n '/static int aw88166_volume_set/,/^}/p' "$K/aw88166.c"
sed -n '/static int aw88166_volume_get/,/^}/p' "$K/aw88166.c"
