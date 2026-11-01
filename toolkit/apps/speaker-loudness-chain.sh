#!/bin/bash
# Insert a PipeWire filter chain between applications and the speaker.
#
# Why this and not the ALSA amp control: this card's ELEM_INFO is broken, so
# PipeWire cannot drive the AW88166 volume - the UI slider does nothing and the
# amp stays at its profile maximum. A filter-chain creates a *virtual* sink; the
# volume of a virtual sink is applied in software, so it works, and the limiter
# catches the peaks that the extra gain would otherwise clip.
set -euo pipefail
CONF=/etc/pipewire/pipewire.conf.d/99-speaker-loudness.conf
mkdir -p /etc/pipewire/pipewire.conf.d

cat > "$CONF" <<'EOF'
# Virtual sink in front of the speaker with a brickwall limiter.
context.modules = [
    {   name = libpipewire-module-filter-chain
        args = {
            node.description = "Speaker (Loudness)"
            media.name       = "Speaker Loudness"
            filter.graph = {
                nodes = [
                    { type = lv2 label = limiter_stereo name = lim
                      control = { "enabled" = 1.0 } }
                ]
            }
            audio.position = [ FL FR ]
            capture.props  = {
                node.name        = "effect_input.speaker_loudness"
                node.description = "Speaker (Loudness)"
                media.class      = "Audio/Sink"
                audio.channels   = 2
            }
            playback.props = {
                node.name        = "effect_output.speaker_loudness"
                node.passive     = true
                node.target      = "alsa_output.platform-sound.HiFi__Speaker__sink"
                audio.channels   = 2
            }
        }
    }
]
EOF

echo "wrote $CONF"
ls -l "$CONF"
